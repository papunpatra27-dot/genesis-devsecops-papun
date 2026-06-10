# iam

This module creates two least-privilege IAM roles and their attached policies: a k3s EC2 node role (ECR image pull, CloudWatch Logs, SSM Session Manager) and a GitHub Actions OIDC-federated deployment role (ECR push, Terraform state read). It also provisions the GitHub Actions OIDC identity provider — no static AWS credentials are ever stored in GitHub Secrets.

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| project | Project name prefix. | string | yes |
| environment | Deployment environment. | string | yes |
| github_org | GitHub organisation name for OIDC trust. | string | yes |
| github_repo | GitHub repository name for OIDC trust. | string | yes |
| ecr_repository_name | ECR repository to scope push/pull permissions. | string | yes |
| state_bucket_name | S3 bucket holding Terraform state. | string | yes |
| state_lock_table_name | DynamoDB table for state locking. | string | yes |

## Outputs

| Name | Description |
|------|-------------|
| k3s_node_role_name | Name of the k3s EC2 node IAM role. |
| k3s_node_role_arn | ARN of the k3s EC2 node IAM role. |
| github_actions_role_arn | ARN of the GitHub Actions deployment role (used in `role-to-assume`). |
| oidc_provider_arn | ARN of the GitHub Actions OIDC provider. |
