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

  # S3 remote backend — bucket and table are injected at init time via
  # -backend-config flags (see the GitHub Actions workflow).
  # Run bootstrap/ first to create the bucket and DynamoDB table.
  backend "s3" {
    key            = "food-delivery/dev/terraform.tfstate"
    encrypt        = true
    # bucket, region, and dynamodb_table are passed via -backend-config
    # when running locally:
    #   terraform init \
    #     -backend-config="bucket=food-delivery-terraform-state-<account_id>" \
    #     -backend-config="region=ca-central-1" \
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
