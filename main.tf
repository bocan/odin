###############################################################################
# Security Group for the Webserver EC2 Instance (odin)
###############################################################################
module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"

  name        = local.name
  description = "Security group for example usage with EC2 instance"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp", "all-icmp", "ssh-tcp"]
  egress_rules        = ["all-all"]

  tags = local.tags
}

###############################################################################
# Security Group for the Mail Server (freyja)
###############################################################################
module "security_group_freyja" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"

  name        = "ex-freyja"
  description = "Security group for example usage with EC2 instance"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["smtp-tcp", "smtp-submission-587-tcp", "smtps-465-tcp", "all-icmp", "ssh-tcp"]

  ingress_with_cidr_blocks = [
    {
      from_port   = 993
      to_port     = 993
      protocol    = "tcp"
      description = "Imaps"
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  egress_rules = ["all-all"]

  tags = local.tags
}


###############################################################################
# EC2 Webserver Module (odin)
###############################################################################
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.1"

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

  ipv6_address_count = 1

  user_data_base64 = base64encode(local.user_data)

  metadata_options = {
    http_tokens = "optional"
  }

  tags               = local.tags
  enable_volume_tags = true

  # The root drive should remain small.
  # The idea here is that the root partitions get updated,
  # but little changes beyond that.
  # Data that needs to persist, should go to /volume
  root_block_device = [
    {
      encrypted   = true
      volume_type = "gp3"
      volume_size = 8
    },
  ]
}

###############################################################################
# EC2 Mail Server Module (freyja)
###############################################################################
module "ec2_instance_freyja" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.1"

  depends_on = [data.aws_ami.encrypted-ami]

  name = "ex-freyja-instance"

  ami                         = coalesce(var.ami_override, data.aws_ami.encrypted-ami.id)
  instance_type               = "t3.medium"
  key_name                    = "freya"
  availability_zone           = element(module.vpc.azs, 0)
  subnet_id                   = element(module.vpc.public_subnets, 0)
  vpc_security_group_ids      = [module.security_group_freyja.security_group_id]
  associate_public_ip_address = true
  iam_instance_profile        = "odin-ec2-profile"

  user_data_base64 = base64encode(local.user_data)

  metadata_options = {
    http_tokens = "optional"
  }

  tags               = local.tags
  enable_volume_tags = false

  # The root drive should remain small.
  # The idea here is that the root partitions get updated,
  # but little changes beyond that.
  # Data that needs to persist, should go to /volume
  root_block_device = [
    {
      encrypted   = true
      volume_type = "gp3"
      volume_size = 8
    },
  ]
}


###############################################################################
# Elastic IP for Webserver (odin)
###############################################################################
resource "aws_eip" "bar" {
  domain = "vpc"

  instance                  = module.ec2_instance.spot_instance_id
  associate_with_private_ip = module.ec2_instance.private_ip

  tags = merge(local.tags, { Name = "${local.name}-eip" })
}

###############################################################################
# Elastic IP for Mail Server (freyja)
###############################################################################
resource "aws_eip" "foo" {
  domain = "vpc"

  instance                  = module.ec2_instance_freyja.id
  associate_with_private_ip = module.ec2_instance_freyja.private_ip

  tags = merge(local.tags, { Name = "ex-freyja-eip" })
}


###############################################################################
# Attach the pre-made large volume for persistant data. (odin)
###############################################################################
resource "aws_volume_attachment" "this" {
  device_name = "/dev/sdh"
  volume_id   = data.aws_ebs_volume.ebs_volume.id
  instance_id = module.ec2_instance.spot_instance_id
}

###############################################################################
# Attach the pre-made large volume for persistant data. (freyja)
###############################################################################
resource "aws_volume_attachment" "this2" {
  device_name = "/dev/sdh"
  volume_id   = data.aws_ebs_volume.ebs_volume_freyja.id
  instance_id = module.ec2_instance_freyja.id
}


resource "aws_route53_record" "mailserverA" {
  zone_id = "ZJLY408K7DRUA"
  ttl     = "300"
  name    = "mail.cloudcauldron.io"
  type    = "A"
  records = [aws_eip.foo.public_ip]
}
