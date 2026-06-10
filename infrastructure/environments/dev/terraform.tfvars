# environments/dev/terraform.tfvars
# ──────────────────────────────────────────────────────────────────────────
# running terraform apply. Never commit real secrets to version control.
# ──────────────────────────────────────────────────────────────────────────

aws_region  = "ap-south-2"
project     = "genesis"
environment = "dev"
owner       = "platform-team"

# Network
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
availability_zones   = ["ap-south-2a", "ap-south-2b"]
admin_cidr           = "106.196.13.220/32"   # system ip

# Compute
ec2_instance_type  = "t2.micro"
k3s_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHqUwvODDeV6fYfSoeC3WuOIwQ6Jn4IRyyoTJGNeBqv6 genesis-k3s"

# GitHub OIDC
github_org  = "papunpatra27-dot"
github_repo = "genesis-devsecops-papun"

# ECR
ecr_repository_name       = "genesis-platform-api"
ecr_image_retention_count = 10

# State backend
state_bucket_name     = "genesis-devsecops-terraform-state-320644184091"
state_lock_table_name = "genesis-terraform-state-lock"

# Observability
log_retention_days = 14
alarm_email        = "papunpatra27@gmail.com"
