output "sns_topic_arn"         { value = aws_sns_topic.alerts.arn }
output "app_log_group_name"    { value = aws_cloudwatch_log_group.app.name }
output "k3s_log_group_name"    { value = aws_cloudwatch_log_group.k3s.name }
