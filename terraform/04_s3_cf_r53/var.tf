
variable "aws_region" {
  default = "ap-northeast-2"
}

variable "domain" {
  default = "alocados.io"
}

variable "sub_domain" {
  default = "tony"
}


variable "s3_bucket_name" {
  type        = string
  description = "The name of the S3 bucket to create."
  default     = "tony-test-04-bucket"
}


variable "duplicate-content-penalty-secret" {
  type    = string
  default = null # If you Required,
}

variable "acm-certificate-arn" {
  type    = string
  default = "" # Requried!!!
}

variable "deployer" {
  type    = string
  default = "tony"
}

variable "default-root-object" {
  type    = string
  default = "index.html"
}

variable "not-found-response-path" {
  type    = string
  default = "/404.html"
}

variable "not-found-response-code" {
  type    = string
  default = "200"
}

variable "tags" {
  type        = map(string)
  description = "Optional Tags"
  default     = {}
}

variable "trusted_signers" {
  type    = list(string)
  default = []
}

variable "forward-query-string" {
  type        = bool
  description = "Forward the query string to the origin"
  default     = true
}

variable "price_class" {
  type        = string
  description = "CloudFront price class"
  default     = "PriceClass_200"
}

variable "ipv6" {
  type        = bool
  description = "Enable IPv6 on CloudFront distribution"
  default     = false
}

variable "minimum_client_tls_protocol_version" {
  type        = string
  description = "CloudFront viewer certificate minimum protocol version"
  default     = "TLSv1"
}

variable "force_destroy" {
  type        = bool
  description = "A boolean that indicates all objects (including any locked objects) should be deleted from the bucket so that the bucket can be destroyed without error. These objects are not recoverable."
  default     = false
}