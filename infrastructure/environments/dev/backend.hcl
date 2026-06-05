# environments/dev/backend.hcl
# Pass this file to terraform init:
#   terraform init -backend-config=backend.hcl

bucket         = "genesis-devsecops-terraform-state-REPLACE_ACCOUNT_ID"
key            = "dev/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "genesis-terraform-state-lock"
encrypt        = true
