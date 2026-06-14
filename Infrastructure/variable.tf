variable "aws_region" {
  description = "AWS region for the prod EKS cluster"
  type        = string
  default     = "ap-south-1"
}

variable "aws_profile" {
  description = "AWS profile for the prod EKS cluster"
  type        = string
  default     = "default"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "ibs-gitops-demo"
}

variable "platform_repo_url" {
  description = "Git URL of this platform repo"
  type        = string
}

variable "github_org" {
  description = "GitHub organization that owns the workload repositories"
  type        = string
  default     = "getsan4u"
}

variable "github_scm_token" {
  description = "GitHub token used by ArgoCD to read private repositories. Do not commit this value."
  type        = string
  sensitive   = true
  default     = ""
}
