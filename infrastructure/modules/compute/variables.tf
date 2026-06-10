variable "project" { type = string }
variable "environment" { type = string }
variable "aws_region" { type = string }
variable "instance_type" {
  description = "EC2 instance type. t2.micro is AWS Free Tier eligible."
  type        = string
  default     = "t2.micro"
}
variable "subnet_id" {
  description = "ID of the public subnet to launch the EC2 instance into."
  type        = string
}
variable "security_group_id" {
  description = "Security group ID to associate with the instance."
  type        = string
}
variable "ssh_public_key" {
  description = "Public SSH key material for the EC2 key pair."
  type        = string
}
variable "k3s_iam_role_name" {
  description = "Name of the IAM role to attach as the instance profile."
  type        = string
}
variable "ecr_registry" {
  description = "ECR registry hostname (account.dkr.ecr.region.amazonaws.com)."
  type        = string
}

variable "common_tags" {
  description = "Mandatory tags applied to every resource: Environment, Project, ManagedBy, Owner."
  type        = map(string)
  default     = {}
}

