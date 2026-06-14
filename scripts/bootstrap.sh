#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="${ROOT_DIR}/Infrastructure"
ROOT_APP_MANIFEST="${ROOT_DIR}/platform/bootstrap/root-app.yaml"

: "${TF_VAR_github_scm_token:?Set TF_VAR_github_scm_token to a GitHub token before bootstrapping}"

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
  --profile "${AWS_PROFILE}"

helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm repo update

helm upgrade --install argocd argo/argo-cd \
  --version 9.0.0 \
  --namespace argocd \
  --create-namespace \
  --set server.service.type=LoadBalancer \
  --wait \
  --timeout 10m

echo "Waiting for ArgoCD server..."
kubectl -n argocd wait deployment argocd-server \
  --for=condition=Available \
  --timeout=300s

echo "Applying ArgoCD root app..."
kubectl apply -f "${ROOT_APP_MANIFEST}"

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
