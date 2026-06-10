##############################################################################
# infrastructure/terraform.tf
# Provider constraints and remote backend configuration.
# Backend values are read from environment-level backend config files to
# keep this file environment-agnostic.
##############################################################################

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Backend is configured per environment via -backend-config flags or
  # environment-specific backend.hcl files. This prevents a single state
  # file from covering both dev and prod.
  backend "s3" {}
}

##############################################################################
# Provider configuration
##############################################################################
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
