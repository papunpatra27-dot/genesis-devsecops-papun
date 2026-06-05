variable "project"              { type = string }
variable "environment"          { type = string }
variable "github_org"           { type = string; description = "GitHub organisation name." }
variable "github_repo"          { type = string; description = "GitHub repository name." }
variable "ecr_repository_name"  { type = string }
variable "state_bucket_name"    { type = string }
variable "state_lock_table_name" { type = string }

variable "common_tags" {
  description = "Mandatory tags applied to every resource: Environment, Project, ManagedBy, Owner."
  type        = map(string)
  default     = {}
}

