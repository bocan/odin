data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["dlm.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "dlm_lifecycle_role" {
  name               = "dlm-lifecycle-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "dlm_lifecycle" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:CreateSnapshot",
      "ec2:CreateSnapshots",
      "ec2:DeleteSnapshot",
      "ec2:DescribeInstances",
      "ec2:DescribeVolumes",
      "ec2:DescribeSnapshots",
    ]

    resources = ["arn:aws:sts:${data.aws_caller_identity.current.account_id}:*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["ec2:CreateTags"]
    resources = ["arn:aws:ec2:${data.aws_caller_identity.current.account_id}::snapshot/*"]
  }
}

resource "aws_iam_role_policy" "dlm_lifecycle" {
  name   = "dlm-lifecycle-policy"
  role   = aws_iam_role.dlm_lifecycle_role.id
  policy = data.aws_iam_policy_document.dlm_lifecycle.json
}

resource "aws_dlm_lifecycle_policy" "odin_dlm_policy" {
  description        = "DLM daily lifecycle policy"
  execution_role_arn = aws_iam_role.dlm_lifecycle_role.arn
  state              = "ENABLED"

  tags = {
    Terraform = "true"
    Name      = "${local.name}_daily_lifecyle"
  }

  policy_details {
    resource_types = ["VOLUME"]

    schedule {
      name = "1 week of twice daily snapshots"

      create_rule {
        cron_expression = "cron(0 4,16 * * ? *)"
      }

      retain_rule {
        count = 14
      }

      tags_to_add = {
        SnapshotCreator = "DLM"
        Type            = "TwiceDaily"
      }

      copy_tags = false
    }

    target_tags = {
      Snapshot = "true"
    }
  }
}

resource "aws_dlm_lifecycle_policy" "odin_dlm_policy_monthly" {
  description        = "DLM monthly lifecycle policy"
  execution_role_arn = aws_iam_role.dlm_lifecycle_role.arn
  state              = "ENABLED"

  tags = {
    Terraform = "true"
    Name      = "${local.name}_monthly_lifecyle"
  }

  policy_details {
    resource_types = ["VOLUME"]

    schedule {
      name = "6 months monthly snapshots"

      create_rule {
        cron_expression = "cron(0 1 22 * ? *)"
      }

      retain_rule {
        count = 6
      }

      tags_to_add = {
        SnapshotCreator = "DLM"
        Type            = "Monthly"
      }

      copy_tags = false
    }

    target_tags = {
      Snapshot = "true"
    }
  }
}
