provider "aws" {
  region = "ap-northeast-2"
}


provider "kubernetes" {
  host = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(
    module.eks.cluster_certificate_authority_data
  )
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.46.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.16.1"
    }
    # random = {
    #   source  = "hashicorp/random"
    #   version = "~> 3.4.3"
    # }

    # tls = {
    #   source  = "hashicorp/tls"
    #   version = "~> 4.0.4"
    # }

    # cloudinit = {
    #   source  = "hashicorp/cloudinit"
    #   version = "~> 2.2.0"
    # }

    

  }
  backend "s3" {
    bucket         = "tony-terraform-state01"
    key            = "06.terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "tony-terraform-state-lock"
    acl            = "bucket-owner-full-control"
  }
}