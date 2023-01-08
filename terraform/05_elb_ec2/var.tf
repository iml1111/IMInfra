variable "author" {
  type = string
  description = "author"
  default = "Tony"
}

variable "domain" {
  type = string
  description = "servcie domain"
  default = "alocados.io"
}

variable "sub_domain" {
  type = string
  description = "sub domain"
  default = "tonyelb"
}

variable "acm_domain" {
  type = string
  description = "ACM domain"
  default = "*.alocados.io"
}

variable "acm-domain" {
  type    = string
  default = "*.alocados.io" # Requried!!!
}

variable "elb_name" {
  type = string
  description = "ELB name"
  default = "tony-05-elb"
}

variable "instance_name" {
  type = string
  description = "EC2 name"
  default = "Tony Web Server"
}

variable "ec2_key_pair_name" {
  type = string
  description = "EC2 Key pair name"
  default = "tony_web_admin"
}

variable "alb_name" {
  type = string
  default = "tony-05-alb"
}

variable "alb_log_bucket_name" {
  type = string
  default = "tony-05-elb-logs"
}

variable "target_group_name" {
  type = string
  default = "tony-05-instance-target-group"
}

variable "num_of_instances" {
  description = "Number of instances to create and attach to ALB"
  type        = string
  default     = 3
}