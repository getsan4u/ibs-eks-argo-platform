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
  description = "GitHub organization for the demo app repositories"
  type        = string
}

variable "github_scm_token" {
  description = "GitHub token for ApplicationSet SCM discovery. Do not commit this value."
  type        = string
  sensitive   = true
  default     = ""
}