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
# CloudWatch Alarms — per instance × failure type
#
# StatusCheckFailed_System   → ec2:recover (migrate to new host, preserves EIP/EBS)
# StatusCheckFailed_Instance → ec2:reboot  (restart OS, for hangs/kernel panics)
###############################################################################
locals {
  ec2_instances = {
    odin   = module.ec2_instance.id
    freyja = module.ec2_instance_freyja.id
  }

  ec2_alarm_types = {
    system = {
      metric      = "StatusCheckFailed_System"
      description = "system (hardware/host) status check failed"
      action      = "arn:aws:automate:eu-west-2:ec2:recover"
    }
    instance = {
      metric      = "StatusCheckFailed_Instance"
      description = "instance (OS) status check failed"
      action      = "arn:aws:automate:eu-west-2:ec2:reboot"
    }
  }

  ec2_alarms = {
    for pair in setproduct(keys(local.ec2_instances), keys(local.ec2_alarm_types)) :
    "${pair[0]}-${pair[1]}" => {
      instance_id = local.ec2_instances[pair[0]]
      instance    = pair[0]
      type        = pair[1]
      metric      = local.ec2_alarm_types[pair[1]].metric
      description = local.ec2_alarm_types[pair[1]].description
      action      = local.ec2_alarm_types[pair[1]].action
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "ec2_status" {
  for_each = local.ec2_alarms

  alarm_name        = "${each.value.instance}-${each.value.type}-check-failed"
  alarm_description = "Fires when the ${each.value.description} on ${each.value.instance}."
  namespace         = "AWS/EC2"
  metric_name       = each.value.metric
  dimensions = {
    InstanceId = each.value.instance_id
  }

  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "breaching"

  alarm_actions = [aws_sns_topic.ec2_alerts.arn, each.value.action]
  ok_actions    = [aws_sns_topic.ec2_alerts.arn]

  tags = merge(local.tags, { Name = "${each.value.instance}-${each.value.type}-check-failed" })
}
