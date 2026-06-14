# IBS EKS ArgoCD Platform

GitOps platform repo. Provisions AWS infrastructure and bootstraps the platform layer for deploying applications via ArgoCD progressive delivery.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Platform Repo (this repo)                                       │
│                                                                 │
│  ┌──────────────────────┐    ┌──────────────────────────────┐  │
│  │  Infrastructure/     │    │  platform/                   │  │
│  │  (Terraform)         │    │  (ArgoCD App-of-Apps)        │  │
│  │                      │    │                              │  │
│  │  vpc.tf              │    │  bootstrap/root-app.yaml     │  │
│  │  eks.tf              │    │  apps/aws-load-balancer-...  │  │
│  │  ecr.tf              │    │  apps/external-secrets.yaml  │  │
│  │  secrets.tf          │    │  apps/kyverno.yaml           │  │
│  │  pod-identity-iam.tf │    │  apps/argo-rollouts.yaml     │  │
│  └──────────────────────┘    │  apps/prod-appproject.yaml   │  │
│                              │  apps/prod-applicationset... │  │
│                              └──────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                    │                        │
                    ▼                        ▼
          AWS Infrastructure          ArgoCD syncs
          (VPC, EKS, ECR,            platform components
          Secrets Manager,            + discovers app repos
          IAM Pod Identity)           via ApplicationSet
```

## What this repo manages

### Infrastructure (Terraform)

| File | What it provisions |
|------|-------------------|
| `vpc.tf` | VPC, 3 AZs, public/private subnets, NAT gateway, ELB subnet tags |
| `eks.tf` | EKS 1.33, managed node group (t3.medium ×2-4), CoreDNS, kube-proxy, vpc-cni, pod-identity-agent |
| `pod-identity-iam.tf` | IAM roles for AWS LBC and External Secrets via EKS Pod Identity |
| `ecr.tf` | Shared ECR registry (`ibs-demo-apps`) with image scanning and 7-day lifecycle |
| `secrets.tf` | Secrets Manager secrets: ArgoCD GitHub SCM token, app demo secrets |

### Platform (ArgoCD App-of-Apps)

`platform/bootstrap/root-app.yaml` is the root ArgoCD Application. It recursively syncs `platform/apps/` which installs and manages:

| Component | Purpose |
|-----------|---------|
| AWS Load Balancer Controller | Provisions ALB/NLB from Kubernetes Ingress/Service |
| External Secrets Operator | Syncs Secrets Manager secrets into Kubernetes Secrets |
| Kyverno | Policy engine — admission control and governance |
| Argo Rollouts | Progressive delivery (canary, blue/green) |
| AppProject + ApplicationSet | ArgoCD project config + SCM-based app discovery for workloads |

## Repository structure

```
.
├── Infrastructure/          # Terraform — AWS infrastructure
│   ├── vpc.tf
│   ├── eks.tf
│   ├── ecr.tf
│   ├── secrets.tf
│   ├── pod-identity-iam.tf
│   ├── providers.tf
│   ├── locals.tf
│   ├── variable.tf
│   ├── outputs.tf
│   ├── versions.tf
│   └── terraform.tfvars.example
├── platform/
│   ├── bootstrap/
│   │   └── root-app.yaml   # ArgoCD root Application (App-of-Apps entry point)
│   └── apps/               # ArgoCD Applications — platform components
├── scripts/
│   ├── bootstrap.sh         # One-time cluster bootstrap
│   └── destroy.sh           # Teardown
└── README.md
```

## Prerequisites

- AWS CLI configured with profile that has admin access
- Terraform >= 1.9
- kubectl
- helm >= 3
- `aws eks get-token` available (included in AWS CLI v2)

## Bootstrap

> Run once. EKS cluster takes ~15 minutes.

```bash
cp Infrastructure/terraform.tfvars.example Infrastructure/terraform.tfvars
# Edit terraform.tfvars — set aws_region, aws_profile, cluster_name, github_org
# Set github_scm_token via env var (do NOT commit it):
export TF_VAR_github_scm_token="ghp_..."

./scripts/bootstrap.sh
```

The script:
1. Runs `terraform init && apply` — provisions VPC, EKS, ECR, IAM, Secrets Manager
2. Updates kubeconfig
3. Installs ArgoCD via Helm
4. Applies root ArgoCD Application — triggers App-of-Apps reconciliation

## Access ArgoCD

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Port-forward (ArgoCD UI at https://localhost:8080)
kubectl -n argocd port-forward svc/argocd-server 8080:443

# Or get the LoadBalancer URL
kubectl -n argocd get svc argocd-server
```

## Terraform outputs

| Output | Value |
|--------|-------|
| `cluster_name` | EKS cluster name |
| `region` | AWS region |
| `ecr_repository_url` | ECR push URL for app CI/CD |
| `aws_load_balancer_controller_role_arn` | IAM role ARN (for reference) |
| `external_secrets_role_arn` | IAM role ARN (for reference) |

## Networking

| Resource | CIDR |
|----------|------|
| VPC | `10.40.0.0/16` |
| Private subnets (EKS nodes) | `10.40.1-3.0/24` |
| Public subnets (LB) | `10.40.101-103.0/24` |

Single NAT gateway (cost-optimised for non-prod).

## Application onboarding

Applications are discovered via the `prod-applicationset.yaml` SCM generator. To onboard a new app:

1. Create application repo under the configured GitHub org
2. ArgoCD ApplicationSet auto-discovers it — no changes to this repo needed
3. Add app secrets to Secrets Manager under `/prod/<app-name>/...` — External Secrets IAM policy allows `/prod/*`

## Teardown

```bash
./scripts/destroy.sh
```

## Key design decisions

**Shared ECR registry** — `ibs-demo-apps` is a single shared registry. Suitable for demo. Production recommendation: per-app ECR repo managed in each application repo.

**EKS Pod Identity** — preferred over IRSA. IAM roles bound at pod level via service account associations in Terraform.

**ArgoCD bootstrapped via Helm** — Helm installs ArgoCD out of band (not managed by ArgoCD itself). ArgoCD then takes over all subsequent platform components via App-of-Apps pattern.

**Single NAT gateway** — reduces cost for demo. Multi-AZ NAT gateways recommended for production.
