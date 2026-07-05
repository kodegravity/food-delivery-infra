variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "food-delivery"
}

variable "state_bucket_name" {
  description = "S3 bucket name for Terraform state. Must be globally unique — append your AWS account ID."
  type        = string
  # Example: "food-delivery-terraform-state-123456789012"
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "food-delivery-terraform-locks"
}
