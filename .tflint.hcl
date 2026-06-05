##############################################################################
# .tflint.hcl — tflint configuration
# Loaded automatically when running `tflint --init` in any directory.
# The AWS plugin enforces AWS provider-specific rules.
##############################################################################

# AWS provider ruleset
plugin "aws" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Core rules
rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}
