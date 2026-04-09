###############################################################################
# SNS Topic for EC2 Status Alerts
###############################################################################
resource "aws_sns_topic" "ec2_alerts" {
  name              = "ec2-status-alerts"
  kms_master_key_id = aws_kms_key.cwlogs.key_id

  tags = merge(local.tags, { Name = "ec2-status-alerts" })
}

resource "aws_sns_topic_subscription" "ec2_alerts_sms" {
  topic_arn = aws_sns_topic.ec2_alerts.arn
  protocol  = "sms"
  endpoint  = var.alert_phone_number
}

###############################################################################
# CloudWatch Alarms — odin
###############################################################################
resource "aws_cloudwatch_metric_alarm" "odin_status_check" {
  alarm_name        = "odin-status-check-failed"
  alarm_description = "Fires when either the instance or system status check fails on odin."
  namespace         = "AWS/EC2"
  metric_name       = "StatusCheckFailed"
  dimensions = {
    InstanceId = module.ec2_instance.id
  }

  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "breaching"

  alarm_actions = [aws_sns_topic.ec2_alerts.arn]
  ok_actions    = [aws_sns_topic.ec2_alerts.arn]

  tags = merge(local.tags, { Name = "odin-status-check-failed" })
}

###############################################################################
# CloudWatch Alarms — freyja
###############################################################################
resource "aws_cloudwatch_metric_alarm" "freyja_status_check" {
  alarm_name        = "freyja-status-check-failed"
  alarm_description = "Fires when either the instance or system status check fails on freyja."
  namespace         = "AWS/EC2"
  metric_name       = "StatusCheckFailed"
  dimensions = {
    InstanceId = module.ec2_instance_freyja.id
  }

  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "breaching"

  alarm_actions = [aws_sns_topic.ec2_alerts.arn]
  ok_actions    = [aws_sns_topic.ec2_alerts.arn]

  tags = merge(local.tags, { Name = "freyja-status-check-failed" })
}
