module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = var.vpc_name

  cidr = "10.0.0.0/16"
  # A, C
  azs  = [
    "${local.region}a", "${local.region}c"
  ]

  public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets  = ["10.0.11.0/24", "10.0.12.0/24"]
  intra_subnets  = ["10.0.21.0/24", "10.0.22.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = false
  one_nat_gateway_per_az = true
  enable_dns_hostnames = true

  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}-cluster" = "shared"
    "kubernetes.io/role/elb"                      = 1
    "karpenter.sh/discovery" = var.cluster_name
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}-cluster" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
    "karpenter.sh/discovery" = var.cluster_name
  }
  vpc_tags = merge(
    local.tags, 
    { 
      Name = var.vpc_name
      "kubernetes.io/cluster/${var.cluster_name}-cluster" = "shared"
    }
  )
  tags = merge(local.tags, { Name = var.vpc_name })
}


# VPC Endpoint
data "aws_security_group" "default" {
  name   = "default"
  vpc_id = module.vpc.vpc_id
}
module "vpc_endpoints" {
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"

  vpc_id = module.vpc.vpc_id
  security_group_ids = [data.aws_security_group.default.id]

  endpoints = {
    s3 = {
      service = "s3"
      service_type    = "Gateway"
      tags = { Name = "${var.vpc_name}-s3-vpc-endpoint" }
    }
  }
}
