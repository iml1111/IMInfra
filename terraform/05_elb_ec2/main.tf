# https://github.com/terraform-aws-modules/terraform-aws-elb/tree/v4.0.0'

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "all" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.default.id
  name   = "default"
}

data "aws_elb_service_account" "this" {}

data "aws_acm_certificate" "this" {
  domain    = var.acm_domain
}

# 테스트를 위해 80, 22번 포트를 전체 개방
resource "aws_security_group" "ssh_and_http" {
  name = "allow_ssh_from_all"
  description = "Allow SSH port from all"
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow_ssh_from_all"
  }
}

# S3 Log Bucket
resource "aws_s3_bucket" "logs" {
  bucket        = var.alb_log_bucket_name
  force_destroy = true
}
resource "aws_s3_bucket_acl" "log" {
  bucket = aws_s3_bucket.logs.id
  acl    = "private"
}
resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.bucket
  policy = data.aws_iam_policy_document.logs.json
}
# ELB ServiceACC에 대한 s3 bucket 작성 권한 할당
data "aws_iam_policy_document" "logs" {
  statement {
    actions = [
      "s3:PutObject",
    ]
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.this.arn]
    }
    resources = [
      "arn:aws:s3:::${var.alb_log_bucket_name}/*",
    ]
  }
}
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.bucket
  
  rule {
    id = "logs_lifecycle"

    # 오래된 로그파일 관리
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 60
      storage_class = "GLACIER"
    }
    expiration {
      days = 90
    }

    filter {
      and {
        prefix = "log/"

        tags = {
          rule      = "log"
          autoclean = "true"
        }
      }
    }
    status = "Enabled"
  }
}


# ALB
resource "aws_lb" "this" {
  name = var.alb_name
  internal = false
  load_balancer_type = "application"
  security_groups = [
    data.aws_security_group.default.id,
    aws_security_group.ssh_and_http.id
  ]
  # Check!!!
  subnets = [
    data.aws_subnets.all.ids[0],
    data.aws_subnets.all.ids[2]
  ]
  # enable_deletion_protection = true
  
  access_logs {
    bucket = aws_s3_bucket.logs.bucket
    prefix = "log"
    enabled = true
  }
  tags = {
    Author = var.author
    Environment = "dev"
  }
}
resource "aws_lb_target_group" "this" {
  name     = var.target_group_name
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    interval            = 30
    path                = "/"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn = data.aws_acm_certificate.this.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
# 추가적인 인증서가 더 필요할 경우
# resource "aws_lb_listener_certificate" "this" {
#   listener_arn    = aws_lb_listener.https.arn
#   certificate_arn = data.aws_acm_certificate.this.arn
# }


# EC2 & Attachment
resource "aws_key_pair" "web_admin" {
  key_name = var.ec2_key_pair_name
  public_key = file("~/.ssh/web_admin.pub")
}
resource "aws_instance" "this" {
  count = var.num_of_instances

  ami = "ami-003bb1772f36a39a3" # 20.04 LTS
  instance_type = "t2.micro"
  key_name = aws_key_pair.web_admin.key_name
  # Test를 위해 모든 IP에게 개방함. 주의 필요.
  vpc_security_group_ids = [
    data.aws_security_group.default.id,
    aws_security_group.ssh_and_http.id,
  ]
  user_data = file("./install_apache.sh")
  tags = {
    Name   = "${var.instance_name} ${count.index}",
    Author = var.author
  }
}
resource "aws_lb_target_group_attachment" "this" {
  count = length(aws_instance.this)
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = aws_instance.this[count.index].id
  port             = 80
}


# Route53 & Domain
data "aws_route53_zone" "this" {
  name = var.domain
}
resource "aws_route53_record" "record" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "${var.sub_domain}.${var.domain}"
  type    = "A"

  alias {
    name = aws_lb.this.dns_name
    zone_id = aws_lb.this.zone_id
    evaluate_target_health = false
  }
}