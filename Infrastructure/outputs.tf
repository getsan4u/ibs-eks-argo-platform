output "cluster_name" {
  value = module.eks.cluster_name
}

output "region" {
  value = var.aws_region
}

output "ecr_repository_url" {
  value = aws_ecr_repository.demo_apps.repository_url
}

output "aws_load_balancer_controller_role_arn" {
  value = module.aws_load_balancer_controller_pod_identity.iam_role_arn
}

output "external_secrets_role_arn" {
  value = module.external_secrets_pod_identity.iam_role_arn
}

output "argocd_server" {
  value = "Run: kubectl -n argocd get svc argocd-server"
}