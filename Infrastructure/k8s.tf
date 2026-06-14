resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"

    labels = {
      name = "argocd"
    }
  }

  depends_on = [
    module.eks
  ]
}

resource "kubernetes_secret_v1" "argocd_github_repo_creds" {
  count = var.github_scm_token == "" ? 0 : 1

  metadata {
    name      = "github-repo-creds"
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name

    labels = {
      "argocd.argoproj.io/secret-type" = "repo-creds"
    }
  }

  type = "Opaque"

  data = {
    type     = "git"
    url      = "https://github.com/${var.github_org}"
    username = var.github_org
    password = var.github_scm_token
  }
}

resource "kubernetes_namespace_v1" "external_secrets" {
  metadata {
    name = "external-secrets"
  }

  depends_on = [
    module.eks
  ]
}

resource "kubernetes_service_account_v1" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = module.aws_load_balancer_controller_pod_identity.iam_role_arn
    }
  }

  depends_on = [
    module.eks
  ]
}

resource "kubernetes_service_account_v1" "external_secrets" {
  metadata {
    name      = "external-secrets"
    namespace = kubernetes_namespace_v1.external_secrets.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = module.external_secrets_pod_identity.iam_role_arn
    }
  }

  depends_on = [
    module.eks,
    kubernetes_namespace_v1.external_secrets
  ]
}
