# Backend configuration for Terraform remote state
# Update the bucket name with your actual S3 bucket name (must include your AWS account ID)
# This should match the bucket created by running terraform apply in the bootstrap/ directory

bucket         = "food-delivery-terraform-state-512383926725"
region         = "us-east-2"
dynamodb_table = "food-delivery-terraform-locks"
