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
  # checkov:skip=CKV_AWS_111:FixMe
  # checkov:skip=CKV_AWS_356:FixMe
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

    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["ec2:CreateTags"]
    resources = ["arn:aws:ec2:*::snapshot/*"]
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
      name = "3 days of twice daily snapshots"

      create_rule {
        cron_expression = "cron(0 8,20 2-31 * ? *)"
      }

      retain_rule {
        count = 6
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
      name = "3 months monthly snapshots"

      create_rule {
        cron_expression = "cron(00 02 01 * ? *)"
      }

      retain_rule {
        count = 3
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
