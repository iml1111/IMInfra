variable "author" {
  type = string
  description = "author"
  default = "Tony"
}

variable "aws_account" {
  type = string
  description = "AWS Account"
  default = "044403692004"
}

variable "aws_iam_username" {
  type = string
  description = "IAM Username"
  default = "tony"
}

variable "vpc_name" {
  type = string
  description = "VPC Name"
  default = "tony-06-vpc"
}

variable "cluster_name" {
  type = string
  description = "EKS Cluster Name"
  default = "tony-06-eks"
}
