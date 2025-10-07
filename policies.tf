#Create a policy
#https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy
resource "aws_iam_policy" "ec2_policy" {
  # checkov:skip=CKV_AWS_355:FixMe
  # checkov:skip=CKV_AWS_290:FixMe
  name        = "odin-ec2-policy"
  path        = "/"
  description = "Policy to provide permission to EC2"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : [
          "ec2:DescribeInstances",
          "ec2:CreateTags",
          "ec2:DescribeSpotInstanceRequests",
          "ec2:ModifyInstanceMetadataOptions",
          "ec2:DescribeRouteTables"
        ],
        "Resource" : "*"
      },
      {
        "Action" : [
          "secretsmanager:GetSecretValue"
        ],
        "Resource" : "arn:aws:secretsmanager:eu-west-2:894121584238:secret:githubToken-4HGaY9",
        "Effect" : "Allow"
      }
    ]
  })
}


#Create a role
#https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
resource "aws_iam_role" "ec2_role" {
  name = "odin-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

#Attach role to policy
#https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
resource "aws_iam_role_policy_attachment" "custom" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_policy.arn
}

#Attach role to an instance profile
#https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "odin-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

#Create a policy
#https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy
resource "aws_iam_policy" "route53_policy" {
  name        = "AllowAWSStuff"
  path        = "/"
  description = "Policy to provide permission to Route53"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "route53:ChangeResourceRecordSets"
        ],
        "Resource" : [
          "arn:aws:route53:::hostedzone/*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "route53:ListHostedZones",
          "route53:ListHostedZonesByName",
          "route53:ListResourceRecordSets",
          "route53:GetChange",
          "route53:ListTagsForResource"
        ],
        "Resource" : [
          "*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:PutRetentionPolicy"
        ],
        "Resource" : [
          aws_cloudwatch_log_group.journal.arn,
          "${aws_cloudwatch_log_group.journal.arn}:*",
          aws_cloudwatch_log_group.docker.arn,
          "${aws_cloudwatch_log_group.docker.arn}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_user" "external-dns-user" {
  name = "external-dns"
}

resource "aws_iam_user_policy_attachment" "attach-ex-dns-user" {
  user       = aws_iam_user.external-dns-user.name
  policy_arn = aws_iam_policy.route53_policy.arn
}
