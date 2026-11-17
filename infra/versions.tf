terraform {
  required_version = ">= 1.10"

  # Configuración real en backend.hcl (bucket, región, bloqueo). Ver infra/README.md.
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
