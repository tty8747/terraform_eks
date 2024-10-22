variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "azs" {
  type    = list(string)
  default = ["eu-central-1a", "eu-central-1b"]
}

variable "aws_access_key_id" {
  type = string
}

variable "aws_secret_access_key" {
  type = string
}

variable "cloudflare_api_token" {
  type = string
}

variable "environment" {
  type    = string
  default = "stage"
}

variable "cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR for vpc"
}

variable "priv_subnets" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "pub_subnets" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "enable_nat_gateway" {
  type = bool
  default = true
}
