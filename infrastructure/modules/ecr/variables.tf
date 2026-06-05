variable "repository_name"        { type = string }
variable "image_retention_count"  { type = number; default = 10 }
variable "github_actions_role_arn" { type = string }
variable "k3s_node_role_arn"       { type = string }

variable "common_tags" {
  description = "Mandatory tags applied to every resource: Environment, Project, ManagedBy, Owner."
  type        = map(string)
  default     = {}
}

