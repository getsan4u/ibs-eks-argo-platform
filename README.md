# Platform and Infrastructure

This repository manages AWS EKS cluster provisioning and shared platform components for the Argo-based platform.

## Overview

- Provision infrastructure for Kubernetes clusters on AWS.
- Manage shared platform resources and common components.
- Keep infrastructure as code for reproducible deployments.

## Contents

- Terraform definitions for EKS cluster provisioning.
- Shared component setup for platform services.
- Configuration and orchestration for Argo workloads.

## Getting Started

1. Review the Terraform configuration files in the repository.
2. Initialize the workspace with `terraform init`.
3. Validate the configuration with `terraform validate`.
4. Apply changes with `terraform apply`.

## Notes

This repository is intended for platform infrastructure teams and is the source of truth for cluster and shared platform provisioning.