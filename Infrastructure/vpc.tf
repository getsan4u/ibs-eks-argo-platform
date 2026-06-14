module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = ">= 6.0"

  name = local.name
  cidr = "10.40.0.0/16"

  azs = local.azs

  private_subnets = [
    "10.40.1.0/24",
    "10.40.2.0/24",
    "10.40.3.0/24"
  ]

  public_subnets = [
    "10.40.101.0/24",
    "10.40.102.0/24",
    "10.40.103.0/24"
  ]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = local.tags
}