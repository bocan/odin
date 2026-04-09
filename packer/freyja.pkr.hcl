###############################################################################
# Source: Debian Trixie (13) — freyja
###############################################################################
source "amazon-ebs" "freyja" {
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

  ami_name        = "freyja-debian-stable-aws-{{timestamp}}"
  ami_description = "Debian Trixie (13) base image for freyja"

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
    Name      = "freyja-debian-stable-aws"
    Series    = "freyja-debian-stable-aws"
    ManagedBy = "Packer"
    Owner     = "Chris Funderburg"
  }
}

###############################################################################
# Build: freyja
###############################################################################
build {
  name    = "freyja"
  sources = ["source.amazon-ebs.freyja"]

  provisioner "shell" {
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
    inline = [
      "set -euo pipefail",

      # Update and upgrade
      "sudo apt-get update -y",
      "sudo apt-get upgrade -y",

      # Base packages (unbound + wget extra for freyja DNS resolver)
      "sudo apt-get install -y ca-certificates curl gnupg jq git dnsutils fail2ban wget unzip unbound apt-transport-https cron gnupg ipset net-tools nftables pre-commit prometheus-node-exporter rsync sqlite3 strace lsb-release",

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

      # Pre-populate Unbound root hints
      "sudo mkdir -p /var/lib/unbound",
      "sudo wget https://www.internic.net/domain/named.root -qO /var/lib/unbound/root.hints",

      # /volume mount point
      "sudo mkdir -p /volume"
    ]
  }
}
