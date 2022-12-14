# https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks
# https://github.com/terraform-aws-modules/terraform-aws-eks
# https://github.com/terraform-aws-modules/terraform-aws-vpc

locals {
  region = "ap-northeast-2"
  tags = {
    Stage = "dev"
    Author = var.author
  }
  stage = "dev"
  # Nodegroup Desized size
  frontend_nodegroup_desired_size = 2
  backend_nodegroup_desired_size = 2
}

data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}


# EKS Cluster & NodeGroup
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.0.4"

  cluster_name    = var.cluster_name
  cluster_version = "1.24"
  cluster_endpoint_public_access = true

  cluster_addons = {
    coredns = {
      preserve    = true
      most_recent = true

      timeouts = {
        create = "25m"
        delete = "10m"
      }
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  # External encryption key
  create_kms_key = false
  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = module.kms.key_arn
  }

  iam_role_additional_policies = {
    additional = aws_iam_policy.additional.arn
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = concat(
    module.vpc.private_subnets, 
    module.vpc.public_subnets
  )
  control_plane_subnet_ids = module.vpc.intra_subnets

  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_security_group_id = aws_security_group.default.id
    }
    ingress_source_security_group_id = {
      description              = "Ingress from another computed security group"
      protocol                 = "tcp"
      from_port                = 22
      to_port                  = 22
      type                     = "ingress"
      source_security_group_id = aws_security_group.default.id
    }
  }

  # Extend node-to-node security group rules
  create_node_security_group = false
  # node_security_group_additional_rules = {
  #   ingress_self_all = {
  #     description = "Node to node all ports/protocols"
  #     protocol    = "-1"
  #     from_port   = 0
  #     to_port     = 0
  #     type        = "ingress"
  #     self        = true
  #   },
  #   ingress_source_security_group_id = {
  #     description              = "Ingress from another computed security group"
  #     protocol                 = "tcp"
  #     from_port                = 22
  #     to_port                  = 22
  #     type                     = "ingress"
  #     source_security_group_id = aws_security_group.default.id
  #   },
  #   metrics-server_ingress = {
  #     description                   = "communication between control plane and the metrics-server endpoint"
  #     protocol                      = "tcp"
  #     from_port                     = "4443"
  #     to_port                       = "4443"
  #     type                          = "ingress"
  #     source_cluster_security_group = true
  #   },
  #   metrics-server_pod_ingress = {
  #     description = "communication between the metrics-server pod and the kubelet running on each worker node"
  #     protocol    = "tcp"
  #     from_port   = "10250"
  #     to_port     = "10250"
  #     type        = "ingress"
  #     self        = true
  #   }
  # }

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    #instance_types = ["m6i.large", "m5.large", "m5n.large", "m5zn.large"]

    attach_cluster_primary_security_group = true
    vpc_security_group_ids = [aws_security_group.default.id]
    iam_role_additional_policies = {
      additional = aws_iam_policy.additional.arn
    }
  }

  eks_managed_node_groups = {
    frontend = {
      name = "frontend-node-group"
      subnet_ids = module.vpc.public_subnets
      instance_types = ["t3.small"]
      capacity_type  = "ON_DEMAND"

      min_size     = 1
      max_size     = 4
      desired_size = local.frontend_nodegroup_desired_size
      disk_size = 20

      update_config = {
        max_unavailable_percentage = 33 
      }

      labels = {
        Stage = "dev"
        Author = var.author
        nodegroup-type = "frontend-node-group"
      }
    }

    backend = {
      name = "backend-node-group"
      subnet_ids = module.vpc.private_subnets
      instance_types = ["t3.small"]
      capacity_type  = "ON_DEMAND"

      min_size     = 1
      max_size     = 4
      desired_size = local.backend_nodegroup_desired_size
      disk_size = 20

      update_config = {
        max_unavailable_percentage = 33 
      }

      labels = {
        Stage = "dev"
        Author = var.author
        nodegroup-type = "backend-node-group"
      }
    }
  }

  # OIDC Identity provider
  cluster_identity_providers = {
    sts = {
      client_id = "sts.amazonaws.com"
    }
  }

  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::${var.aws_account}:user/${var.aws_iam_username}"
      username = var.aws_iam_username
      groups   = ["system:masters"]
    }
  ]

  aws_auth_accounts = [
    var.aws_account
  ]

  tags = merge(local.tags, { "karpenter.sh/discovery" = var.cluster_name })

}
# https://github.com/bryantbiggs/eks-desired-size-hack
resource "null_resource" "update_frontend_desired_size" {
  triggers = {
    desired_size = local.frontend_nodegroup_desired_size
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    command     = <<-EOT
      aws eks update-nodegroup-config --cluster-name ${module.eks.cluster_name} --nodegroup-name ${element(split(":", module.eks.eks_managed_node_groups["frontend"].node_group_id), 1)} --scaling-config desiredSize=${local.frontend_nodegroup_desired_size}
    EOT
  }

  depends_on = [
    module.eks
  ]
}
resource "null_resource" "update_backend_desired_size" {
  triggers = {
    desired_size = local.backend_nodegroup_desired_size
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    command     = <<-EOT
      aws eks update-nodegroup-config --cluster-name ${module.eks.cluster_name} --nodegroup-name ${element(split(":", module.eks.eks_managed_node_groups["backend"].node_group_id), 1)} --scaling-config desiredSize=${local.backend_nodegroup_desired_size}
    EOT
  }
  depends_on = [
    module.eks
  ]
}

resource "aws_iam_policy" "additional" {
  name = "${var.cluster_name}-additional"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "1.3.0"

  aliases               = ["eks/${var.cluster_name}"]
  description           = "${var.cluster_name} cluster encryption key"
  enable_default_policy = true
  key_owners            = [data.aws_caller_identity.current.arn]

  tags = local.tags
}

