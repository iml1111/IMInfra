provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_instance" "tony_test_ec2" {
  ami           = "ami-0e17ad9abf7e5c818" # Amazon Linux 2
  instance_type = "t2.micro"
  tags = {
    Name   = "Tony Web Server",
    Author = "Tony"
  }
}