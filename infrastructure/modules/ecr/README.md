# ecr

This module creates an ECR private repository configured for production use: `imageTagMutability = IMMUTABLE` prevents tag overwriting, `scanOnPush = true` triggers Enhanced scanning on every push, and a lifecycle policy caps storage costs by expiring untagged images after one day and retaining only the last N git-SHA-tagged images. A repository policy restricts write access to the GitHub Actions OIDC role and read access to the k3s node role.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| repository_name | ECR repository name. | string | — | yes |
| image_retention_count | Number of tagged images to retain. | number | 10 | no |
| github_actions_role_arn | ARN of the GitHub Actions role allowed to push. | string | — | yes |
| k3s_node_role_arn | ARN of the k3s node role allowed to pull. | string | — | yes |

## Outputs

| Name | Description |
|------|-------------|
| repository_url | Full ECR repository URL. |
| repository_name | Repository name. |
| registry_id | AWS account ID acting as the registry. |
