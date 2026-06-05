# environments/prod/backend.hcl
bucket         = "genesis-devsecops-terraform-state-REPLACE_ACCOUNT_ID"
key            = "prod/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "genesis-terraform-state-lock"
encrypt        = true
