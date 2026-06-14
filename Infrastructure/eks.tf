module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = ">= 21.0"

  name               = local.name
  kubernetes_version = "1.33"

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets


  endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  eks_managed_node_groups = {
    prod_default = {
      name           = "prod-default"
      instance_types = ["t3.medium"]

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
      }

      min_size     = 2
      max_size     = 4
      desired_size = 2
    }
  }

  tags = local.tags
}
