#!/usr/bin/env bash
set -euo pipefail

echo "Enter your GitHub organization name (e.g., ibs):"
read -r github_org


ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="${ROOT_DIR}/infrastructure"
ROOT_APP_MANIFEST="${ROOT_DIR}/platform/bootstrap/root-app.yaml"

echo "Bootstrapping prod EKS GitOps platform..."

cd "${INFRA_DIR}"

terraform init
terraform apply -auto-approve

CLUSTER_NAME="$(terraform output -raw cluster_name)"
REGION="$(terraform output -raw region)"
AWS_PROFILE="$(terraform output -raw aws_profile)"

aws eks update-kubeconfig \
  --region "${REGION}" \
  --name "${CLUSTER_NAME}" \
  --profile $AWS_PROFILE

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --set server.service.type=LoadBalancer \
  --wait \
  --timeout 300s\
  --debug
  
echo "Waiting for ArgoCD server..."
kubectl -n argocd wait deployment argocd-server \
  --for=condition=Available \
  --timeout=300s

echo "Applying ArgoCD root app..."
sed "s|\$github_org|${github_org}|g" "${ROOT_APP_MANIFEST}" | kubectl apply -f -


echo "Checking ArgoCD root app..."
kubectl -n argocd get application prod-root

echo "Bootstrap complete."

echo ""
echo "ArgoCD server:"
kubectl -n argocd get svc argocd-server

echo ""
echo "Initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

echo ""
echo ""
echo "Port-forward ArgoCD:"
echo "kubectl -n argocd port-forward svc/argocd-server 8080:443"