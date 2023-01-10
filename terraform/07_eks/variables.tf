variable "author" {
  type = string
  description = "author"
  default = "Tony"
}

variable "vpc_name" {
  type = string
  description = "VPC Name"
  default = "tony-06-eks-vpc"
}

variable "cluster_name" {
  type = string
  description = "EKS Cluster Name"
  default = "tony-06-eks"
}
