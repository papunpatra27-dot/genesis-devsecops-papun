# compute

This module launches the EC2 t3.micro instance that runs a k3s single-node Kubernetes cluster and attaches the IAM instance profile created by the `iam` module. The user-data script installs k3s, Helm, Argo CD, Kyverno, and the Prometheus stack automatically on first boot.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project | Project name prefix. | string | — | yes |
| environment | Deployment environment. | string | — | yes |
| aws_region | AWS region. | string | — | yes |
| instance_type | EC2 instance type. | string | t3.micro | no |
| subnet_id | Public subnet ID to launch into. | string | — | yes |
| security_group_id | Security group ID for the instance. | string | — | yes |
| ssh_public_key | Public SSH key material. | string | — | yes |
| k3s_iam_role_name | IAM role name for the instance profile. | string | — | yes |
| ecr_registry | ECR registry hostname. | string | — | yes |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | EC2 instance ID. |
| public_ip | Elastic IP attached to the instance. |
| private_ip | Private IP of the instance. |
| instance_profile | IAM instance profile name. |
