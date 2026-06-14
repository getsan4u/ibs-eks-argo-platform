resource "aws_secretsmanager_secret" "canary_demo" {
  name = "/prod/canary-demo/secret-message"

  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "canary_demo" {
  secret_id = aws_secretsmanager_secret.canary_demo.id

  secret_string = jsonencode({
    SECRET_MESSAGE = "hello-from-aws-secrets-manager"
  })
}

resource "aws_secretsmanager_secret" "argocd_github_scm_token" {
  name = "/prod/argocd/github-scm-token"

  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "argocd_github_scm_token" {
  count = var.github_scm_token == "" ? 0 : 1

  secret_id = aws_secretsmanager_secret.argocd_github_scm_token.id

  secret_string = jsonencode({
    token = var.github_scm_token
  })
}