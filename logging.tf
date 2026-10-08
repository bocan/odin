# The CloudWatch log groups are gone - this key now only encrypts the
# ec2-status-alerts SNS topic in alerting.tf.
resource "aws_kms_key" "cwlogs" {
  description             = "KMS for CloudWatch Logs"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # 1) Root/admin access
      {
        Sid       = "AllowRoot"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      # 2) CloudWatch Logs service needs Encrypt/Decrypt etc.
      {
        Sid       = "AllowCloudWatchLogsService"
        Effect    = "Allow"
        Principal = { Service = "logs.amazonaws.com" }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      },
      # 3) SNS service needs Encrypt/Decrypt for topic at-rest encryption
      {
        Sid       = "AllowSNSService"
        Effect    = "Allow"
        Principal = { Service = "sns.amazonaws.com" }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "cwlogs" {
  name          = "alias/cwlogs"
  target_key_id = aws_kms_key.cwlogs.key_id
}
