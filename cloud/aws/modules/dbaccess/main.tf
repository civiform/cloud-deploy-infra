# Security group to allow the host's IP inbound
resource "aws_security_group" "dbaccess_security_group" {
  name        = "${var.app_prefix}-dbaccess-sg"
  description = "Allow inbound traffic to dbaccess EC2 instance"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.cidr_allowlist
    description = "Allow SSH access to temporary EC2 host"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    description = "Allow HTTPS access to update and install packages"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    description = "Allow HTTP access to update and install packages"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name   = "${var.app_prefix}-dbaccess-sg"
    Module = "dbaccess"
  }
}

resource "aws_security_group_rule" "dbaccess_egress_postgres" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  description              = "Allow dbaccess EC2 instance to connect to RDS instance"
  security_group_id        = aws_security_group.dbaccess_security_group.id
  source_security_group_id = var.db_sg_id

}

resource "aws_key_pair" "dbaccess_key_pair" {
  key_name   = "dbaccess-key-pair"
  public_key = file(var.public_key)

  tags = {
    Name   = "${var.app_prefix}-dbaccess-key-pair"
    Module = "dbaccess"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical official

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
resource "aws_instance" "dbaccess_host" {
  ami             = data.aws_ami.ubuntu.image_id
  instance_type   = var.host_type
  key_name        = aws_key_pair.dbaccess_key_pair.key_name
  security_groups = [aws_security_group.dbaccess_security_group.id]
  subnet_id       = var.public_subnet

  tags = {
    Name   = "${var.app_prefix}-dbaccess-host"
    Module = "dbaccess"
  }
}

output "host_private_ip" {
  value = aws_instance.dbaccess_host.private_ip
}