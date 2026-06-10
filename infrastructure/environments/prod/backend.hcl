# environments/prod/backend.hcl
bucket         = "genesis-devsecops-terraform-state-320644184091"
key            = "prod/terraform.tfstate"
region         = "ap-south-1"
dynamodb_table = "genesis-terraform-state-lock"
encrypt        = true

