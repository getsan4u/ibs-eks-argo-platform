#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="${ROOT_DIR}/Infrastructure"
AWS_PROFILE_ARGS=()

cd "${INFRA_DIR}"

terraform_output() {
  local name="$1"
  terraform output -raw "${name}" 2>/dev/null || true
}

aws_cli() {
  aws --region "${REGION}" "${AWS_PROFILE_ARGS[@]}" "$@"
}

kubectl_has_resource() {
  kubectl api-resources --api-group="${1}" --no-headers 2>/dev/null | awk '{print $1}' | grep -qx "${2}"
}

kubectl_delete_if_present() {
  local resource="$1"
  local namespace="$2"

  if [[ -n "${namespace}" ]] && kubectl get namespace "${namespace}" >/dev/null 2>&1; then
    kubectl delete "${resource}" --all -n "${namespace}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  fi
}

remove_argocd_finalizers() {
  local resource="$1"
  local namespace="argocd"

  if ! kubectl get namespace "${namespace}" >/dev/null 2>&1; then
    return
  fi

  while IFS= read -r name; do
    [[ -z "${name}" ]] && continue
    kubectl patch "${name}" -n "${namespace}" --type=merge -p '{"metadata":{"finalizers":[]}}' >/dev/null 2>&1 || true
  done < <(kubectl get "${resource}" -n "${namespace}" -o name 2>/dev/null || true)
}

remove_ingress_finalizers() {
  while IFS= read -r item; do
    [[ -z "${item}" ]] && continue
    local namespace="${item%%/*}"
    local name="${item#*/}"
    kubectl patch ingress "${name}" -n "${namespace}" --type=merge -p '{"metadata":{"finalizers":[]}}' >/dev/null 2>&1 || true
  done < <(kubectl get ingress -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
}

delete_load_balancer_services() {
  while IFS= read -r item; do
    [[ -z "${item}" ]] && continue
    local namespace="${item%%/*}"
    local name="${item#*/}"
    kubectl delete service "${name}" -n "${namespace}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  done < <(kubectl get services -A -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.namespace}{"/"}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
}

wait_for_aws_load_balancers() {
  local vpc_id="$1"
  [[ -z "${vpc_id}" ]] && return

  for _ in {1..30}; do
    local count
    count="$(aws_cli elbv2 describe-load-balancers \
      --query "length(LoadBalancers[?VpcId=='${vpc_id}'])" \
      --output text 2>/dev/null || echo 0)"

    [[ "${count}" == "0" ]] && return
    sleep 10
  done
}

delete_leftover_k8s_security_groups() {
  local vpc_id="$1"
  [[ -z "${vpc_id}" ]] && return

  while IFS= read -r group_id; do
    [[ -z "${group_id}" ]] && continue
    aws_cli ec2 delete-security-group --group-id "${group_id}" >/dev/null 2>&1 || true
  done < <(aws_cli ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=${vpc_id}" \
    --query "SecurityGroups[?GroupName!='default' && starts_with(GroupName, 'k8s-')].GroupId" \
    --output text 2>/dev/null | tr '\t' '\n')
}

pre_destroy_cleanup() {
  echo ""
  echo "Running best-effort pre-destroy cleanup..."

  REGION="$(terraform_output region)"
  REGION="${REGION:-${AWS_REGION:-ap-south-1}}"

  local aws_profile
  aws_profile="$(terraform_output aws_profile)"
  aws_profile="${aws_profile:-${AWS_PROFILE:-default}}"
  if [[ -n "${aws_profile}" && "${aws_profile}" != "default" ]]; then
    AWS_PROFILE_ARGS=(--profile "${aws_profile}")
  else
    AWS_PROFILE_ARGS=()
  fi

  CLUSTER_NAME="$(terraform_output cluster_name)"
  CLUSTER_NAME="${CLUSTER_NAME:-ibs-gitops-demo}"

  VPC_ID="$(aws_cli eks describe-cluster \
    --name "${CLUSTER_NAME}" \
    --query "cluster.resourcesVpcConfig.vpcId" \
    --output text 2>/dev/null || true)"
  [[ "${VPC_ID}" == "None" ]] && VPC_ID=""

  if [[ -n "${VPC_ID}" ]] && command -v kubectl >/dev/null 2>&1; then
    aws_cli eks update-kubeconfig --name "${CLUSTER_NAME}" >/dev/null 2>&1 || true

    if kubectl cluster-info >/dev/null 2>&1; then
      if kubectl_has_resource "argoproj.io" "applicationsets"; then
        kubectl_delete_if_present "applicationsets.argoproj.io" "argocd"
      fi

      if kubectl_has_resource "argoproj.io" "applications"; then
        kubectl_delete_if_present "applications.argoproj.io" "argocd"
      fi

      delete_load_balancer_services
      kubectl delete ingress --all -A --ignore-not-found --wait=false >/dev/null 2>&1 || true

      wait_for_aws_load_balancers "${VPC_ID}"

      remove_ingress_finalizers
      remove_argocd_finalizers "applications.argoproj.io"
      remove_argocd_finalizers "applicationsets.argoproj.io"
    fi

    wait_for_aws_load_balancers "${VPC_ID}"
    delete_leftover_k8s_security_groups "${VPC_ID}"
  fi

  echo "Pre-destroy cleanup complete."
  echo ""
}

echo "This will destroy Terraform-managed resources in:"
echo "  ${INFRA_DIR}"
echo ""
echo "Terraform workspace:"
terraform workspace show
echo ""
read -r -p "Type destroy to continue: " CONFIRM

if [[ "${CONFIRM}" != "destroy" ]]; then
  echo "Destroy cancelled."
  exit 1
fi

pre_destroy_cleanup
terraform destroy
