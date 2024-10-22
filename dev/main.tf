terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "4.44.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "5.72.1"
    }
  }
}

provider "aws" {
  region     = var.region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

module "vpc" {
  source = "../modules/vpc"
  region = var.region
  azs = var.azs
  environment = var.environment
  cidr = var.cidr
  priv_subnets = var.priv_subnets
  pub_subnets = var.pub_subnets
  enable_nat_gateway = var.enable_nat_gateway
}
