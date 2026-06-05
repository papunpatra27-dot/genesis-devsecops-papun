# environments/dev/terraform.tfvars
# ──────────────────────────────────────────────────────────────────────────
# Replace placeholder values (prefixed REPLACE_) with actual values before
# running terraform apply. Never commit real secrets to version control.
# ──────────────────────────────────────────────────────────────────────────

aws_region  = "us-east-1"
project     = "genesis"
environment = "dev"
owner       = "platform-team"

# Network
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]
admin_cidr           = "0.0.0.0/0"   # Restrict to your IP in production

# Compute
ec2_instance_type  = "t2.micro"
k3s_ssh_public_key = "REPLACE_WITH_YOUR_PUBLIC_SSH_KEY"

# GitHub OIDC
github_org  = "REPLACE_WITH_GITHUB_ORG"
github_repo = "genesis-devsecops-papun"

# ECR
ecr_repository_name       = "genesis-platform-api"
ecr_image_retention_count = 10

# State backend
state_bucket_name     = "genesis-devsecops-terraform-state-REPLACE_ACCOUNT_ID"
state_lock_table_name = "genesis-terraform-state-lock"

# Observability
log_retention_days = 14
alarm_email        = "REPLACE_WITH_YOUR_EMAIL@example.com"
