# networking

This module creates the core network layer for a single-region deployment. It provisions a VPC with public and private subnets spread across two availability zones, an Internet Gateway with a public route table, security groups tailored for a k3s Kubernetes node, and VPC Flow Logs published to CloudWatch for network audit trails.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project | Short project identifier used as a resource name prefix. | string | — | yes |
| environment | Deployment environment (dev \| staging \| prod). | string | — | yes |
| vpc_cidr | Primary CIDR block for the VPC. | string | — | yes |
| public_subnet_cidrs | CIDR blocks for public subnets, one per AZ. | list(string) | — | yes |
| private_subnet_cidrs | CIDR blocks for private subnets, one per AZ. | list(string) | — | yes |
| availability_zones | AZs to distribute subnets across. | list(string) | — | yes |
| admin_cidr | CIDR allowed to reach SSH and the K8s API. | string | 0.0.0.0/0 | no |
| log_retention_days | CloudWatch log retention in days. | number | 30 | no |
| kms_key_arn | KMS key ARN for CloudWatch log encryption. | string | null | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | ID of the created VPC. |
| vpc_cidr_block | CIDR block of the VPC. |
| public_subnet_ids | List of public subnet IDs. |
| private_subnet_ids | List of private subnet IDs. |
| k3s_security_group_id | Security group ID for the k3s node. |
| internet_gateway_id | ID of the Internet Gateway. |
