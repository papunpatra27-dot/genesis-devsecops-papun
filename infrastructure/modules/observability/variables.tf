variable "project"           { type = string }
variable "environment"       { type = string }
variable "log_retention_days" {
  type = number
  default = 30
}
variable "alarm_email"       { type = string }
variable "ec2_instance_id"   { type = string }

variable "common_tags" {
  description = "Mandatory tags applied to every resource: Environment, Project, ManagedBy, Owner."
  type        = map(string)
  default     = {}
}

