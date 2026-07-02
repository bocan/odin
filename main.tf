###############################################################################
# Security Group for the Webserver EC2 Instance (odin)
###############################################################################
module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "6.0.0"

  name        = local.name
  description = "Security group for example usage with EC2 instance"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    https-from-anywhere = {
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = "0.0.0.0/0"
      description = "HTTPS from Anywhere"
    }

    https-from-anywhere-ipv6 = {
      from_port   = 443
      to_port     = 443
      cidr_ipv6   = "::/0"
      description = "HTTPS from Anywhere"
    }

    http-from-ipv4 = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "HTTP from IPv4"
    }

    http-from-ipv6 = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv6   = "::/0"
      description = "HTTP from IPv6"
    }

    icmp-from-anywhere = {
      from_port   = -1
      to_port     = -1
      cidr_ipv4   = "0.0.0.0/0"
      ip_protocol = "icmp"
      description = "ICMP from Anywhere"
    }

    all-from-self = {
      ip_protocol                  = "-1"
      referenced_security_group_id = "self"
      description                  = "All protocols from self"
    }

    ssh-from-anywhere = {
      from_port   = 22
      to_port     = 22
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "SSH from anywhere"
    }

  }

  egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  tags = local.tags
}

###############################################################################
# Security Group for the Mail Server (freyja)
###############################################################################
module "security_group_freyja" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "6.0.0"

  name        = "ex-freyja"
  description = "Security group for example usage with EC2 instance"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    smtp-from-anywhere = {
      from_port   = 25
      to_port     = 25
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "SMTP from Anywhere"
    }

    smtp-sub-from-anywhere = {
      from_port   = 587
      to_port     = 587
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "SMTP Sub from Anywhere"
    }

    smtps-from-anywhere = {
      from_port   = 465
      to_port     = 465
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "SMTPS from Anywhere"
    }

    imaps-from-anywhere = {
      from_port   = 993
      to_port     = 993
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Imaps"
    }

    prometheus-node-exporter-from-anywhere = {
      from_port   = 9100
      to_port     = 9100
      ip_protocol = "tcp"
      cidr_ipv4   = "5.64.0.0/13"
      description = "prometheus-node-exporter"
    }

    icmp-from-anywhere = {
      from_port   = -1
      to_port     = -1
      ip_protocol = "icmp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "ICMP from Anywhere"
    }

    all-from-self = {
      ip_protocol                  = "-1"
      referenced_security_group_id = "self"
      description                  = "All protocols from self"
    }

    ssh-from-anywhere = {
      from_port   = 22
      to_port     = 22
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "SSH from anywhere"
    }

    https-from-anywhere = {
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = "0.0.0.0/0"
      description = "HTTPS from Anywhere"
    }

    http-from-ipv4 = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "HTTP from IPv4"
    }

  }

  egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  tags = local.tags
}


###############################################################################
# EC2 Webserver Module (odin)
###############################################################################
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "6.4.0"

  depends_on = [data.aws_ami.odin-ami]

  name = "${local.name}-instance"

  ami                         = data.aws_ami.odin-ami.id
  instance_type               = "t3.medium"
  key_name                    = "freya"
  availability_zone           = element(module.vpc.azs, 0)
  subnet_id                   = element(module.vpc.public_subnets, 0)
  vpc_security_group_ids      = [module.security_group.id]
  associate_public_ip_address = true
  iam_instance_profile        = "odin-ec2-profile"

  ipv6_addresses = var.ipv6_addresses

  user_data_base64 = base64encode(local.odin_user_data)

  metadata_options = {
    http_tokens = "required"
  }

  tags               = local.tags
  enable_volume_tags = false

  # The root drive should remain small.
  # The idea here is that the root partitions get updated,
  # but little changes beyond that.
  # Data that needs to persist, should go to /volume
  root_block_device = {
    encrypted = true
    type      = "gp3"
    size      = 8
    tags      = merge(local.tags, { Name = "odin-root" })
  }

}

###############################################################################
# EC2 Mail Server Module (freyja)
###############################################################################
module "ec2_instance_freyja" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "6.4.0"

  depends_on = [data.aws_ami.freyja-ami]

  name = "ex-freyja-instance"

  ami                         = data.aws_ami.freyja-ami.id
  instance_type               = "t3.medium"
  key_name                    = "freya"
  availability_zone           = element(module.vpc.azs, 0)
  subnet_id                   = element(module.vpc.public_subnets, 0)
  vpc_security_group_ids      = [module.security_group_freyja.id]
  associate_public_ip_address = true
  iam_instance_profile        = "odin-ec2-profile"

  user_data_base64   = base64encode(local.freyja_user_data)
  ipv6_address_count = 0

  metadata_options = {
    http_tokens = "required"
  }

  tags               = local.tags
  enable_volume_tags = false

  # The root drive should remain small.
  # The idea here is that the root partitions get updated,
  # but little changes beyond that.
  # Data that needs to persist, should go to /volume
  root_block_device = {
    encrypted = true
    type      = "gp3"
    size      = 8
    tags      = merge(local.tags, { Name = "freyja-root" })
  }
}


###############################################################################
# Elastic IP for Webserver (odin)
###############################################################################
resource "aws_eip" "bar" {
  domain = "vpc"

  instance                  = module.ec2_instance.id
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
  instance_id = module.ec2_instance.id
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

resource "aws_route53_record" "statusserverA" {
  zone_id = "ZJLY408K7DRUA"
  ttl     = "300"
  name    = "status.cloudcauldron.io"
  type    = "A"
  records = [aws_eip.foo.public_ip]
}

resource "aws_route53_record" "webserverAAAA" {
  zone_id = "Z040675438FCVAX53GWAN"
  ttl     = "300"
  name    = "chris.funderburg.me"
  type    = "AAAA"
  records = module.ec2_instance.ipv6_addresses

}
