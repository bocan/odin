# I know I'm using the KMS module elsewhere - but there's no point in
# that when it's literally just these 2 resources.
resource "aws_kms_key" "cwlogs" {
  description             = "KMS for CloudWatch Logs"
  deletion_window_in_days = 7

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
      }
    ]
  })
}

resource "aws_kms_alias" "cwlogs" {
  name          = "alias/cwlogs"
  target_key_id = aws_kms_key.cwlogs.key_id
}

# Clouwwatch Log Groups for Linux and Docker logs

resource "aws_cloudwatch_log_group" "journal" {
  name              = "${local.name}/journal"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.cwlogs.arn
}

resource "aws_cloudwatch_log_group" "docker" {
  name              = "${local.name}/docker"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.cwlogs.arn
}
