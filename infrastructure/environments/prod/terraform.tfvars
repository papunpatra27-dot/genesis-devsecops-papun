# environments/prod/terraform.tfvars

aws_region  = "ap-south-2"
project     = "genesis"
environment = "prod"
owner       = "platform-team"

vpc_cidr             = "10.1.0.0/16"
public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]
availability_zones   = ["ap-south-2a", "ap-south-2b"]
admin_cidr           = "REPLACE_WITH_VPN_OR_BASTION_CIDR"

ec2_instance_type  = "t2.micro"
k3s_ssh_public_key = "REPLACE_WITH_YOUR_PUBLIC_SSH_KEY"

github_org  = "REPLACE_WITH_GITHUB_ORG"
github_repo = "genesis-devsecops-papun"

ecr_repository_name       = "genesis-platform-api"
ecr_image_retention_count = 20

state_bucket_name     = "genesis-devsecops-terraform-state-320644184091"
state_lock_table_name = "genesis-terraform-state-lock"

log_retention_days = 90
alarm_email        = "REPLACE_WITH_OPS_EMAIL@example.com"

