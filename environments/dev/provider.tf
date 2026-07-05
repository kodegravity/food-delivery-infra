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

  # S3 remote backend — bucket and dynamodb_table are injected at init time via
  # -backend-config flags (see the GitHub Actions workflow).
  # Note: we use 'skip_region_validation = true' because the S3 backend validates
  # the region before applying -backend-config flags, which causes issues in CI/CD.
  backend "s3" {
    key                      = "food-delivery/dev/terraform.tfstate"
    encrypt                  = true
    skip_region_validation   = true
    skip_credentials_validation = true
    # These are passed via -backend-config at runtime:
    #   terraform init \
    #     -backend-config="bucket=food-delivery-terraform-state-<account_id>" \
    #     -backend-config="region=us-east-2" \
    #     -backend-config="dynamodb_table=food-delivery-terraform-locks"
  }
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
