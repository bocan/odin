provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

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

data "aws_ami" "encrypted-ami" {
  most_recent = true

  depends_on = [aws_ami_copy.debian_encrypted_ami]
  filter {
    name   = "name"
    values = [aws_ami_copy.debian_encrypted_ami.name]
  }

  owners = ["self"]
}

locals {
  name   = "ex-${basename(path.cwd)}"
  region = "eu-west-2"

  vpc_cidr = "10.2.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  user_data = templatefile("${path.module}/user_data.sh", {
    GITHUB_USER  = var.github_user
    GITHUB_TOKEN = var.github_token
  })

  tags = {
    "kubernetes.io/cluster/k0s" = "owned"
  }
  me = var.users_for_key
}



################################################################################
# VPC Module
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.12.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 4)]

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = false
  enable_flow_log    = false

  enable_ipv6                                   = false
  public_subnet_assign_ipv6_address_on_creation = false

  tags = local.tags
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.2"

  name        = local.name
  description = "Security group for example usage with EC2 instance"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp", "all-icmp", "ssh-tcp"]
  egress_rules        = ["all-all"]

  tags = local.tags
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.6.1"

  depends_on = [data.aws_ami.encrypted-ami]

  name = "${local.name}-spot-instance"

  ami                         = coalesce(var.ami_override, data.aws_ami.encrypted-ami.id)
  create_spot_instance        = true
  instance_type               = "t3.medium"
  key_name                    = "freya"
  availability_zone           = element(module.vpc.azs, 0)
  subnet_id                   = element(module.vpc.public_subnets, 0)
  vpc_security_group_ids      = [module.security_group.security_group_id]
  associate_public_ip_address = true
  iam_instance_profile        = "odin-ec2-profile"

  # Spot request specific attributes
  spot_wait_for_fulfillment           = true
  spot_type                           = "persistent"
  spot_instance_interruption_behavior = "stop"
  # End spot request specific attributes

  user_data_base64 = base64encode(local.user_data)

  metadata_options = {
    http_tokens = "required"
  }

  tags               = local.tags
  enable_volume_tags = true
  root_block_device = [
    {
      encrypted   = true
      volume_type = "gp3"
      volume_size = 8
    },
  ]
}


resource "aws_eip" "bar" {
  domain = "vpc"

  instance                  = module.ec2_instance.spot_instance_id
  associate_with_private_ip = module.ec2_instance.private_ip

  tags = merge(local.tags, { Name = "${local.name}-eip" })
}

resource "aws_volume_attachment" "this" {
  device_name = "/dev/sdh"
  volume_id   = data.aws_ebs_volume.ebs_volume.id
  instance_id = module.ec2_instance.spot_instance_id
}


module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "3.1.0"

  description              = "AMI Encryption Key"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"

  # Aliases
  aliases                 = ["odin/ami-encryption-key"]
  aliases_use_name_prefix = true

  key_owners = local.me

  # I'm hijacking this for spot instances.
  key_service_roles_for_autoscaling = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/spot.amazonaws.com/AWSServiceRoleForEC2Spot"]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
