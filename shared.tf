provider "aws" {
  region = local.region
  default_tags {
    tags = local.tags
  }
}

data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

###############################################################################
# AMI Building
###############################################################################

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

data "aws_ami" "odin-ami" {
  most_recent = true

  filter {
    name   = "tag:Series"
    values = ["odin-debian-stable-aws"]
  }

  owners = ["self"]
}

data "aws_ami" "freyja-ami" {
  most_recent = true

  filter {
    name   = "tag:Series"
    values = ["freyja-debian-stable-aws"]
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

  odin_user_data = templatefile("${path.module}/odin_user_data.sh", {
    GITHUB_USER  = var.github_user
    GITHUB_TOKEN = var.github_token
  })
  freyja_user_data = templatefile("${path.module}/freyja_user_data.sh", {
    GITHUB_USER  = var.github_user
    GITHUB_TOKEN = var.github_token
  })

  tags = {
    ManagedBy = "Terraform",
    Owner     = "Chris Funderburg"
  }
  me = var.users_for_key
}



###############################################################################
# VPC Module
###############################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.5.1"

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
  version = "4.1.1"

  description              = "AMI Encryption Key"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"

  # Aliases
  aliases                 = ["odin/ami-encryption-key"]
  aliases_use_name_prefix = true

  key_owners = local.me

  # I'm hijacking this for spot instances.
  key_service_roles_for_autoscaling = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/spot.amazonaws.com/AWSServiceRoleForEC2Spot"]

  tags = local.tags

}
