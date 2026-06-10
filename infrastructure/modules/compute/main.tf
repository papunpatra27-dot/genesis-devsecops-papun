##############################################################################
# modules/compute/main.tf
# Provisions the EC2 t2.micro instance that hosts the k3s Kubernetes cluster,
# a matching key pair, and the IAM instance profile.
##############################################################################

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

##############################################################################
# Key pair
##############################################################################
resource "aws_key_pair" "k3s" {
  key_name   = "${var.project}-${var.environment}-k3s-key"
  public_key = var.ssh_public_key

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-k3s-key"
  })
}

##############################################################################
# EC2 instance — k3s single-node cluster
##############################################################################
resource "aws_instance" "k3s" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = aws_key_pair.k3s.key_name
  iam_instance_profile   = aws_iam_instance_profile.k3s.name

  # Disable IMDSv1 — require IMDSv2 token-based access
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true

    tags = merge(var.common_tags, {
      Name = "${var.project}-${var.environment}-k3s-root"
    })
  }

  user_data = templatefile("${path.module}/userdata.sh.tpl", {
    project     = var.project
    environment = var.environment
    aws_region  = var.aws_region
    ecr_registry = var.ecr_registry
  })

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-k3s-node"
    Role = "k3s-control-plane"
  })

  lifecycle {
    ignore_changes = [ami] # Prevent forced replacement on new AMI releases
  }
}

##############################################################################
# Elastic IP (stable public endpoint for Argo CD / kubectl)
##############################################################################
resource "aws_eip" "k3s" {
  instance = aws_instance.k3s.id
  domain   = "vpc"

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-k3s-eip"
  })
}

##############################################################################
# IAM instance profile
##############################################################################
resource "aws_iam_instance_profile" "k3s" {
  name = "${var.project}-${var.environment}-k3s-instance-profile"
  role = var.k3s_iam_role_name

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-k3s-instance-profile"
  })
}
