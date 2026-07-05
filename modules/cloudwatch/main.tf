resource "aws_cloudwatch_log_group" "services" {
  for_each = toset(var.service_names)

  name              = "/ecs/${var.project}/${var.environment}/${each.key}"
  retention_in_days = var.retention_days

  tags = merge(var.tags, {
    Name    = "/ecs/${var.project}/${var.environment}/${each.key}"
    Service = each.key
  })
}
