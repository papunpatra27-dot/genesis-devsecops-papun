# observability

This module provisions supplementary AWS-native observability: two CloudWatch log groups (application and k3s system), an SNS topic with email subscription for alarm routing, and three CloudWatch alarms (high CPU, EC2 status-check failure, and application 5xx error rate). It complements the in-cluster Prometheus/Grafana stack with durable AWS-side telemetry and paging.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project | Project name prefix. | string | — | yes |
| environment | Deployment environment. | string | — | yes |
| log_retention_days | CloudWatch log retention in days. | number | 30 | no |
| alarm_email | Email for alarm notifications via SNS. | string | — | yes |
| ec2_instance_id | EC2 instance ID of the k3s node. | string | — | yes |

## Outputs

| Name | Description |
|------|-------------|
| sns_topic_arn | ARN of the alerts SNS topic. |
| app_log_group_name | Name of the application CloudWatch log group. |
| k3s_log_group_name | Name of the k3s system CloudWatch log group. |
