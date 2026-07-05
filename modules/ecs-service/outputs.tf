output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.service.name
}

output "service_id" {
  description = "ID of the ECS service"
  value       = aws_ecs_service.service.id
}

output "task_definition_arn" {
  description = "ARN of the current task definition"
  value       = aws_ecs_task_definition.service.arn
}

output "task_definition_family" {
  description = "Family of the task definition"
  value       = aws_ecs_task_definition.service.family
}
