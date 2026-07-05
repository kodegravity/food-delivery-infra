output "state_bucket_name" {
  description = "S3 bucket name — add this as a GitHub Actions variable: TF_STATE_BUCKET"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "dynamodb_table_name" {
  description = "DynamoDB table name — add this as a GitHub Actions variable: TF_STATE_DYNAMODB_TABLE"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "next_steps" {
  description = "What to do after running this bootstrap"
  value       = <<-EOT
    Bootstrap complete! Now:
    1. Go to GitHub → Settings → Secrets and variables → Actions
    2. Add these Repository Secrets:
       AWS_ACCESS_KEY_ID     = <your IAM key>
       AWS_SECRET_ACCESS_KEY = <your IAM secret>
    3. Add these Repository Variables:
       TF_STATE_BUCKET       = ${aws_s3_bucket.terraform_state.bucket}
       TF_STATE_DYNAMODB_TABLE = ${aws_dynamodb_table.terraform_locks.name}
       AWS_REGION            = ${var.aws_region}
    4. Run the 'Terraform Deploy' workflow from the Actions tab.
  EOT
}
