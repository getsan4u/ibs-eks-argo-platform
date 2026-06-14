module "aws_load_balancer_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = ">= 2.8"

  name = "${local.name}-aws-lbc"

  attach_aws_lb_controller_policy = true

  associations = {
    aws_lbc = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
    }
  }

  tags = local.tags
}

module "external_secrets_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = ">= 2.8"

  name = "${local.name}-external-secrets"

  attach_external_secrets_policy = true

  external_secrets_secrets_manager_arns = [
    aws_secretsmanager_secret.canary_demo.arn,
    aws_secretsmanager_secret.argocd_github_scm_token.arn
  ]

  associations = {
    external_secrets = {
      cluster_name    = module.eks.cluster_name
      namespace       = "external-secrets"
      service_account = "external-secrets"
    }
  }

  tags = local.tags
}