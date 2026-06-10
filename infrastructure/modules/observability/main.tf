##############################################################################
# modules/observability/main.tf
# Creates supplementary AWS observability resources:
#   - CloudWatch log group for the application
#   - SNS topic + email subscription for alert notifications
#   - CloudWatch alarms: CPU utilisation and instance status check
##############################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

##############################################################################
# CloudWatch Log Group — application logs from k3s/fluentbit
##############################################################################
resource "aws_cloudwatch_log_group" "app" {
  name              = "/genesis/${var.project}-${var.environment}/app"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-app-logs"
  })
}

resource "aws_cloudwatch_log_group" "k3s" {
  name              = "/genesis/${var.project}-${var.environment}/k3s"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-k3s-logs"
  })
}

##############################################################################
# SNS Topic — alarm notifications
##############################################################################
resource "aws_sns_topic" "alerts" {
  name              = "${var.project}-${var.environment}-alerts"
  kms_master_key_id = "alias/aws/sns"

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-alerts"
  })
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

##############################################################################
# CloudWatch Alarms
##############################################################################

# High CPU — k3s might be overloaded (t3.micro is burstable)
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project}-${var.environment}-k3s-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "k3s node CPU >= 80% for 10 minutes — investigate for node pressure."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = var.ec2_instance_id
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-k3s-cpu-high"
  })
}

# Instance status check failure
resource "aws_cloudwatch_metric_alarm" "status_check" {
  alarm_name          = "${var.project}-${var.environment}-k3s-status-check"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "EC2 status check failed — instance may be unhealthy."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "breaching"

  dimensions = {
    InstanceId = var.ec2_instance_id
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-k3s-status-check"
  })
}

# CloudWatch Alarm — error rate from application logs
resource "aws_cloudwatch_metric_alarm" "app_error_rate" {
  alarm_name          = "${var.project}-${var.environment}-app-error-rate"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "5xxErrors"
  namespace           = "${var.project}/API"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "More than 10 HTTP 5xx errors in a 5-minute window."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-app-error-rate"
  })
}
