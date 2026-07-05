output "alb_sg_id" {
  description = "Security group ID for the ALB"
  value       = aws_security_group.alb.id
}

output "api_gateway_sg_id" {
  description = "Security group ID for the api-gateway ECS service"
  value       = aws_security_group.api_gateway.id
}

output "backend_services_sg_id" {
  description = "Security group ID for backend ECS services"
  value       = aws_security_group.backend_services.id
}

output "rds_sg_id" {
  description = "Security group ID for the RDS instance"
  value       = aws_security_group.rds.id
}
