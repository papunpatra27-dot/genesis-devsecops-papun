variable "project" {
  description = "Short project identifier used as a resource name prefix."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev | staging | prod)."
  type        = string
}

variable "vpc_cidr" {
  description = "Primary CIDR block for the VPC."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per availability zone."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per availability zone."
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability zones to distribute subnets across."
  type        = list(string)
}

variable "admin_cidr" {
  description = "CIDR block allowed to reach SSH (port 22) and the Kubernetes API (port 6443). Restrict to a bastion or VPN range in production."
  type        = string
  default     = "0.0.0.0/0"
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days."
  type        = number
  default     = 30
}

variable "kms_key_arn" {
  description = "ARN of KMS key used to encrypt CloudWatch log groups. Pass empty string to use default encryption."
  type        = string
  default     = null
}

variable "common_tags" {
  description = "Mandatory tags applied to every resource: Environment, Project, ManagedBy, Owner."
  type        = map(string)
  default     = {}
}
