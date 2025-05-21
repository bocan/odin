

resource "aws_s3_bucket" "nextcloud_storage" {
  bucket = "cloudcauldron-nextcloud-s3"
  #checkov:skip=CKV_AWS_18:I don't want yet another bucket for logging.
  #checkov:skip=CKV_AWS_144:No need for cross-region replicaiton yet.
  #checkov:skip=CKV_AWS_145:It's encrypted. And I'm not a bank.
  #checkov:skip=CKV2_AWS_61:Interface is changing too much.
  #checkov:skip=CKV2_AWS_62:This failed when I tried to implement it.

  tags = merge(local.tags, { Name = "nextcloud-storage" })
}

resource "aws_s3_bucket_versioning" "nextcloud_versioning" {
  bucket = aws_s3_bucket.nextcloud_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "nextcloud_encryption" {
  bucket = aws_s3_bucket.nextcloud_storage.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "nextcloud_owner" {
  bucket = aws_s3_bucket.nextcloud_storage.id
  rule {
    #    object_ownership = "BucketOwnerPreferred"
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_acl" "nextcloud_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.nextcloud_owner]

  bucket = aws_s3_bucket.nextcloud_storage.id
  acl    = "private"
}

resource "aws_iam_user" "nextcloud_user" {
  #checkov:skip=CKV_AWS_273:I want an explicit IAM user for this service.
  name = "nextcloud-s3-user"

  tags = merge(local.tags, { Name = "nextcloud-s3-user" })
}

resource "aws_iam_policy" "nextcloud_s3_policy" {
  name        = "nextcloud-s3-access-policy"
  description = "Policy to allow Nextcloud user access to the specific S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketVersioning",
        ]
        Resource = [
          aws_s3_bucket.nextcloud_storage.arn,
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",      # Recommended for versioning
          "s3:GetObjectVersion",         # Recommended for versioning
          "s3:ListMultipartUploadParts", # Required for large file uploads
          "s3:AbortMultipartUpload"      # Required for large file uploads
        ]
        Resource = [
          "${aws_s3_bucket.nextcloud_storage.arn}/*",
        ]
      }
    ]
  })

  tags = merge(local.tags, { Name = "nextcloud-s3-access-policy" })
}

resource "aws_iam_user_policy_attachment" "nextcloud_policy_attachment" {
  #checkov:skip=CKV_AWS_40:I want an explicit IAM user for this service.
  user       = aws_iam_user.nextcloud_user.name
  policy_arn = aws_iam_policy.nextcloud_s3_policy.arn
}

resource "aws_iam_access_key" "nextcloud_access_key" {
  user = aws_iam_user.nextcloud_user.name
}

# Output the Access Key and Secret Key
output "nextcloud_s3_access_key_id" {
  value = nonsensitive(aws_iam_access_key.nextcloud_access_key.id)
}

output "nextcloud_s3_secret_access_key" {
  value = nonsensitive(aws_iam_access_key.nextcloud_access_key.secret)
}

output "nextcloud_s3_bucket_name" {
  value = aws_s3_bucket.nextcloud_storage.bucket
}

resource "aws_s3_bucket_public_access_block" "nextcloud_access_good" {
  bucket = aws_s3_bucket.nextcloud_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
