# Bootstrap — one-time setup
#
# Run this ONCE from your local machine before using the GitHub Actions pipeline.
# It creates the S3 bucket and DynamoDB table that Terraform uses to store remote state.
#
# Usage:
#   cd bootstrap
#   terraform init
#   terraform apply
#   # Note the outputs — add them as GitHub Actions variables (see README)

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Bootstrap itself uses local state (it is the thing that creates remote state)
}

provider "aws" {
  region = var.aws_region
}

locals {
  tags = {
    Project     = var.project
    ManagedBy   = "terraform"
    Purpose     = "terraform-state"
  }
}

# ── S3 bucket for Terraform state ────────────────────────────────────────────

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  # Prevent accidental deletion of state
  lifecycle {
    prevent_destroy = true
  }

  tags = merge(local.tags, {
    Name = var.state_bucket_name
  })
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── DynamoDB table for state locking ─────────────────────────────────────────

resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(local.tags, {
    Name = var.dynamodb_table_name
  })
}
