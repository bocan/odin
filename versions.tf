terraform {
  required_version = ">= 1.9.0"

  backend "s3" {
    bucket         = "odin-tfstate"
    key            = "states/terraform.tfstate"
    dynamodb_table = "odin-tf-state"
    region         = "eu-west-2"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
  encryption {
    key_provider "pbkdf2" "mykey" {
      passphrase = var.passphrase
    }

    method "aes_gcm" "new_method" {
      keys = key_provider.pbkdf2.mykey
    }

    state {
      method   = method.aes_gcm.new_method
      enforced = true
    }
    plan {
      method   = method.aes_gcm.new_method
      enforced = true
    }
  }
}
