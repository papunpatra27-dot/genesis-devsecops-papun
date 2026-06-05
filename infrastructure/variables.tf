##############################################################################
# infrastructure/variables.tf
# Global variable declarations shared across all environments.
##############################################################################

variable "aws_region" {
  description = "AWS region to deploy resources into."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Short project identifier. Used as a prefix on all resource names."
  type        = string
  default     = "genesis"
}

variable "environment" {
  description = "Deployment environment name (dev | staging | prod)."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "owner" {
  description = "Team or individual owning the resources. Applied as a tag."
  type        = string
  default     = "platform-team"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets (one per AZ)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets (one per AZ)."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "availability_zones" {
  description = "List of AZs to distribute subnets across."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "ec2_instance_type" {
  description = "EC2 instance type for the k3s control-plane node. Free tier: t2.micro."
  type        = string
  default     = "t2.micro"
}

variable "k3s_ssh_public_key" {
  description = "Public SSH key material for the k3s EC2 key pair."
  type        = string
  sensitive   = false # Public key is not secret
}

variable "github_org" {
  description = "GitHub organisation name for the OIDC trust policy."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (without org prefix) for the OIDC trust policy."
  type        = string
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository for the platform API image."
  type        = string
  default     = "genesis-platform-api"
}

variable "ecr_image_retention_count" {
  description = "Number of tagged images to retain in ECR before the lifecycle policy purges older ones."
  type        = number
  default     = 10
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket that stores Terraform remote state."
  type        = string
}

variable "state_lock_table_name" {
  description = "Name of the DynamoDB table used for Terraform state locking."
  type        = string
  default     = "genesis-terraform-state-lock"
}

variable "log_retention_days" {
  description = "Retention period in days for CloudWatch log groups."
  type        = number
  default     = 30
}

variable "alarm_email" {
  description = "Email address that receives CloudWatch alarm notifications via SNS."
  type        = string
}
