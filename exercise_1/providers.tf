terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region     = var.region
  access_key = "AKIATYTXYTCM3ZR3G4GK"
  secret_key = "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"
}

data "aws_availability_zones" "zones" {
  #name = var.region
  state = "available"

}