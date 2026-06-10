##############################################################################
# environments/dev/main.tf
# Wires all modules together for the dev environment.
# Backend is configured via environments/dev/backend.hcl (passed with
# `terraform init -backend-config=backend.hcl`).
##############################################################################

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.50"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
    }
  }
}

# ---------------------------------------------------------------------------
# Local: common_tags is passed to every module so resources are tagged
# consistently even when modules are used outside this environment config.
# ---------------------------------------------------------------------------
locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
  }
}

##############################################################################
# Networking
##############################################################################
module "networking" {
  source = "../../modules/networking"

  project              = var.project
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  admin_cidr           = var.admin_cidr
  log_retention_days   = var.log_retention_days
  common_tags          = local.common_tags
}

##############################################################################
# IAM
##############################################################################
module "iam" {
  source = "../../modules/iam"

  project                = var.project
  environment            = var.environment
  github_org             = var.github_org
  github_repo            = var.github_repo
  ecr_repository_name    = var.ecr_repository_name
  state_bucket_name      = var.state_bucket_name
  state_lock_table_name  = var.state_lock_table_name
  common_tags            = local.common_tags
}

##############################################################################
# ECR
##############################################################################
module "ecr" {
  source = "../../modules/ecr"

  repository_name         = var.ecr_repository_name
  image_retention_count   = var.ecr_image_retention_count
  github_actions_role_arn = module.iam.github_actions_role_arn
  k3s_node_role_arn       = module.iam.k3s_node_role_arn
  common_tags             = local.common_tags
}

##############################################################################
# Compute (depends on networking + iam + ecr)
##############################################################################
module "compute" {
  source = "../../modules/compute"

  project           = var.project
  environment       = var.environment
  aws_region        = var.aws_region
  instance_type     = var.ec2_instance_type
  subnet_id         = module.networking.public_subnet_ids[0]
  security_group_id = module.networking.k3s_security_group_id
  ssh_public_key    = var.k3s_ssh_public_key
  k3s_iam_role_name = module.iam.k3s_node_role_name
  ecr_registry      = "${module.ecr.registry_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  common_tags       = local.common_tags
}

##############################################################################
# Observability
##############################################################################
module "observability" {
  source = "../../modules/observability"

  project            = var.project
  environment        = var.environment
  log_retention_days = var.log_retention_days
  alarm_email        = var.alarm_email
  ec2_instance_id    = module.compute.instance_id
  common_tags        = local.common_tags
}

##############################################################################
# Outputs
##############################################################################
output "k3s_public_ip"          { value = module.compute.public_ip }
output "ecr_repository_url"     { value = module.ecr.repository_url }
output "github_actions_role_arn" { value = module.iam.github_actions_role_arn }
