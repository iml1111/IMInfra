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
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}-cluster" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
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
data "aws_vpc_endpoint_service" "s3" {
  service_type = "Interface"
  filter {
    name   = "service-name"
    values = ["*s3"]
  }
}
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = data.aws_vpc_endpoint_service.s3.service_name
  vpc_endpoint_type = "Interface"

  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  subnet_ids          = module.vpc.private_subnets_ids 
  private_dns_enabled = false

  tags = merge(local.tags, { Name = "${var.cluster_name}-s3-endpoint" })
}

data "aws_vpc_endpoint_service" "ecr" {
  service_type = "Interface"
  filter {
    name   = "service-name"
    values = ["*ecr.dkr*"]
  }
}
resource "aws_vpc_endpoint" "ecr" {
  vpc_id            = module.vpc.vpc_id 
  service_name      = data.aws_vpc_endpoint_service.ecr_dkr.service_name
  vpc_endpoint_type = "Interface"

  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  subnet_ids          = module.main_vpc.private_subnets_ids
  private_dns_enabled = false
  
  tags = merge(local.tags, { Name = "${local.name_prefix}-ecr-endpoint" })
}
