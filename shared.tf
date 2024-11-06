provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

###############################################################################
# AMI Building
###############################################################################

#
# Find the latest Debian Sid Public AMI
#
data "aws_ami" "debian" {
  most_recent = true
  owners      = ["903794441882"]

  filter {
    name   = "name"
    values = ["debian-sid-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

#
# Find my pre-existing storage volumes
# to keep permanent data on.
#
data "aws_ebs_volume" "ebs_volume" {
  most_recent = true

  filter {
    name   = "volume-type"
    values = ["gp3"]
  }

  filter {
    name   = "tag:Name"
    values = ["odin-data"]
  }
}

data "aws_ebs_volume" "ebs_volume_freyja" {
  most_recent = true

  filter {
    name   = "volume-type"
    values = ["gp3"]
  }

  filter {
    name   = "tag:Name"
    values = ["freyja-data"]
  }
}


#
# Make an encrypted AMI with the non-encrypted public AMI.
# Use a customer managed key.
#
resource "aws_ami_copy" "debian_encrypted_ami" {
  name              = "debian-encrypted-ami"
  description       = "An encrypted root ami based off ${data.aws_ami.debian.id}"
  source_ami_id     = data.aws_ami.debian.id
  source_ami_region = "eu-west-2"
  encrypted         = true
  kms_key_id        = module.kms.key_arn

  depends_on = [data.aws_ami.debian]
  tags       = { Name = "debian-encrypted-ami" }
}

#
# IIRC, I had to do this as the above isn't instantly ready.
#
data "aws_ami" "encrypted-ami" {
  most_recent = true

  depends_on = [aws_ami_copy.debian_encrypted_ami]
  filter {
    name   = "name"
    values = [aws_ami_copy.debian_encrypted_ami.name]
  }

  owners = ["self"]
}

###############################################################################
# Locals
###############################################################################
locals {
  name   = "ex-${basename(path.cwd)}"
  region = "eu-west-2"

  vpc_cidr = "10.2.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  user_data = templatefile("${path.module}/user_data.sh", {
    GITHUB_USER  = var.github_user
    GITHUB_TOKEN = var.github_token
  })

  # TODO - I don't actually need this.
  tags = {
    "kubernetes.io/cluster/k0s" = "owned"
  }
  me = var.users_for_key
}



###############################################################################
# VPC Module
###############################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.15.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 4)]

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = false
  enable_flow_log    = false

  enable_ipv6                                   = true
  public_subnet_assign_ipv6_address_on_creation = true

  public_subnet_ipv6_prefixes  = [0, 1, 2]
  private_subnet_ipv6_prefixes = [3, 4, 5]

  tags = local.tags
}

###############################################################################
# Create a customer managed key with the KMS Module
###############################################################################
module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "3.1.1"

  description              = "AMI Encryption Key"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"

  # Aliases
  aliases                 = ["odin/ami-encryption-key"]
  aliases_use_name_prefix = true

  key_owners = local.me

  # I'm hijacking this for spot instances.
  key_service_roles_for_autoscaling = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/spot.amazonaws.com/AWSServiceRoleForEC2Spot"]

  tags = {
    Terraform = "true"
  }
}
