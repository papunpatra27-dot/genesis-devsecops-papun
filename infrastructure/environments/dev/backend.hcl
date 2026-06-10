# environments/dev/backend.hcl
# Pass this file to terraform init:
#   terraform init -backend-config=backend.hcl

bucket         = "genesis-devsecops-terraform-state-320644184091"
key            = "dev/terraform.tfstate"
region         = "ap-south-2"
dynamodb_table = "genesis-terraform-state-lock"
encrypt        = true
