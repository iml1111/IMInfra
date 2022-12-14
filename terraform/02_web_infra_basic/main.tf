resource "aws_key_pair" "web_admin" {
  key_name = "tony_web_admin"
  public_key = file("~/.ssh/web_admin.pub")
}

resource "aws_security_group" "ssh" {
  name = "allow_ssh_from_all"
  description = "Allow SSH port from all"
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow_ssh_from_all"
  }
}

data "aws_security_group" "default" {
  name = "default"
}

resource "aws_instance" "web" {
  ami = "ami-003bb1772f36a39a3" # 20.04 LTS
  instance_type = "t2.micro"
  key_name = aws_key_pair.web_admin.key_name
  vpc_security_group_ids = [
    aws_security_group.ssh.id,
    data.aws_security_group.default.id
  ]
  tags = {
    Name = "tony_web"
  }
}

resource "aws_db_instance" "web_db" {
  allocated_storage = 8
  engine = "mysql"
  # rds 대시보드에 뜨는 이름
  identifier = "tonydb01"
  instance_class = "db.t2.micro"
  db_name = "tony_web_db_name"
  username = "admin"
  password = "tony1234"
  publicly_accessible = true
  skip_final_snapshot = true
  tags = {
    Name = "tony_web_db"
  }
}