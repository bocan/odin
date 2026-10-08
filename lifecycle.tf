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
  # Describe actions do not support resource-level restrictions
  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeVolumes",
      "ec2:DescribeSnapshots",
    ]

    resources = ["*"]
  }

  # CreateSnapshot is authorised against both the source volume and the new
  # snapshot. Only volumes that opt in with the Snapshot tag can be a source.
  statement {
    effect    = "Allow"
    actions   = ["ec2:CreateSnapshot"]
    resources = ["arn:aws:ec2:*:*:volume/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Snapshot"
      values   = ["true"]
    }
  }

  # The new snapshot has no tags yet, so this one can't be tag-conditioned.
  statement {
    effect = "Allow"

    actions = [
      "ec2:CreateSnapshot",
      "ec2:CreateTags",
    ]

    resources = ["arn:aws:ec2:*::snapshot/*"]
  }

  # DLM may only delete the snapshots it made itself
  statement {
    effect    = "Allow"
    actions   = ["ec2:DeleteSnapshot"]
    resources = ["arn:aws:ec2:*::snapshot/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/SnapshotCreator"
      values   = ["DLM"]
    }
  }
}

resource "aws_iam_role_policy" "dlm_lifecycle" {
  name   = "dlm-lifecycle-policy"
  role   = aws_iam_role.dlm_lifecycle_role.id
  policy = data.aws_iam_policy_document.dlm_lifecycle.json
}

#
# The data volumes pre-date this repo and are only looked up, not managed,
# so opt them in to the DLM policy by managing just the one tag.
#
resource "aws_ec2_tag" "data_volume_snapshot" {
  for_each = {
    odin   = data.aws_ebs_volume.ebs_volume.id
    freyja = data.aws_ebs_volume.ebs_volume_freyja.id
  }

  resource_id = each.value
  key         = "Snapshot"
  value       = "true"
}

resource "aws_dlm_lifecycle_policy" "odin_dlm_policy_weekly" {
  description        = "DLM weekly lifecycle policy"
  execution_role_arn = aws_iam_role.dlm_lifecycle_role.arn
  state              = "ENABLED"

  tags = {
    Terraform = "true"
    Name      = "${local.name}_weekly_lifecyle"
  }

  policy_details {
    resource_types = ["VOLUME"]

    schedule {
      name = "Weekly snapshot keep the latest"

      # Sundays at 03:00 UTC
      create_rule {
        cron_expression = "cron(0 3 ? * SUN *)"
      }

      retain_rule {
        count = 1
      }

      tags_to_add = {
        SnapshotCreator = "DLM"
        Type            = "Weekly"
      }

      copy_tags = false
    }

    target_tags = {
      Snapshot = "true"
    }
  }

  depends_on = [
    aws_iam_role_policy.dlm_lifecycle,
    aws_ec2_tag.data_volume_snapshot,
  ]
}
