terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Local backend for now — state is stored in .terraform/terraform.tfstate
  # To migrate to S3 backend later, uncomment the backend "s3" block below
  # and run: terraform init -migrate-state
  #
  # backend "s3" {
  #   key                      = "food-delivery/dev/terraform.tfstate"
  #   encrypt                  = true
  #   skip_region_validation   = true
  #   skip_credentials_validation = true
  #   # bucket, region, dynamodb_table passed via -backend-config at init time
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
