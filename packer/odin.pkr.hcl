###############################################################################
# Source: Debian Trixie (13) — odin
###############################################################################
source "amazon-ebs" "odin" {
  region        = "eu-west-2"
  instance_type = "t3.medium"
  ssh_username  = "admin"

  vpc_filter {
    filters = {
      "tag:Name" = "ex-odin"
    }
  }

  subnet_filter {
    filters = {
      "tag:Name" = "ex-odin-public-eu-west-2a"
    }
    most_free = true
    random    = false
  }

  associate_public_ip_address = true
  iam_instance_profile        = "odin-ec2-profile"

  ami_name        = "odin-debian-stable-aws-{{timestamp}}"
  ami_description = "Debian Trixie (13) base image for odin"

  source_ami_filter {
    filters = {
      name                = "debian-13-amd64-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["136693071363"] # Official Debian AWS account
  }

  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_type           = "gp3"
    volume_size           = 8
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name      = "odin-debian-stable-aws"
    Series    = "odin-debian-stable-aws"
    ManagedBy = "Packer"
    Owner     = "Chris Funderburg"
  }
}

###############################################################################
# Build: odin
###############################################################################
build {
  name    = "odin"
  sources = ["source.amazon-ebs.odin"]

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    inline = [
      "set -euo pipefail",

      # Update and upgrade
      "sudo apt-get update -y",
      "sudo apt-get upgrade -y",

      # Base packages
      "sudo apt-get install -y ca-certificates curl gnupg jq git dnsutils fail2ban wget unzip acct apt-transport-https aspell cron ipset lsb-release lsof net-tools nftables nmap pre-commit prometheus-node-exporter python3 rsync strace",

      # Docker apt repo
      "sudo install -m 0755 -d /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg",
      "sudo chmod a+r /etc/apt/keyrings/docker.gpg",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update -y",
      "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "sudo systemctl enable docker",

      # AWS CLI v2
      "curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscliv2.zip",
      "unzip -q /tmp/awscliv2.zip -d /tmp",
      "sudo /tmp/aws/install",
      "rm -rf /tmp/awscliv2.zip /tmp/aws",

      # AWS SSM Agent
      "curl -fsSL https://s3.eu-west-2.amazonaws.com/amazon-ssm-eu-west-2/latest/debian_amd64/amazon-ssm-agent.deb -o /tmp/amazon-ssm-agent.deb",
      "sudo dpkg -i /tmp/amazon-ssm-agent.deb",
      "rm -f /tmp/amazon-ssm-agent.deb",
      "sudo systemctl enable amazon-ssm-agent",

      # /volume mount point
      "sudo mkdir -p /volume"
    ]
  }
}
