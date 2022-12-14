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
}

data "aws_canonical_user_id" "current" {}

resource "aws_dynamodb_table" "terraform_state_lock" {
  name = "tony-terraform-state-lock"
  read_capacity = 5
  write_capacity = 5
  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# 테라폼 액세스 로그
resource "aws_s3_bucket" "terraform_logs" {
  bucket = "tony-terraform-logs01"
}
resource "aws_s3_bucket_acl" "terraform_logs_acl" {
  bucket = aws_s3_bucket.terraform_logs.id
  acl = "log-delivery-write"
}


# 테라폼 스테이트
resource "aws_s3_bucket" "terraform_state" {
  bucket = "tony-terraform-state01"
  tags = {
    Name = "terraform_state"
  }
}
resource "aws_s3_bucket_acl" "terraform_state_acl" {
  bucket = aws_s3_bucket.terraform_state.id
  acl    = "private"
}
resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_logging" "terraform_state_logging" {
  bucket = aws_s3_bucket.terraform_state.id
  target_bucket = aws_s3_bucket.terraform_logs.id
  target_prefix = "log/"
}