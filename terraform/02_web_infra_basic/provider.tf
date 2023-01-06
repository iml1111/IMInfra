provider "aws" {
  region = "ap-northeast-2"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  backend "s3" {
    bucket = "tony-terraform-state01"
    key = "terraform.tfstate"
    region = "ap-northeast-2"
    encrypt = true
    dynamodb_table = "tony-terraform-state-lock"
    acl = "bucket-owner-full-control"
  }
}

