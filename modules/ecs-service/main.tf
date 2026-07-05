locals {
  container_definition = {
    name      = var.service_name
    image     = var.container_image
    essential = true

    portMappings = [
      {
        containerPort = var.container_port
        hostPort      = var.container_port
        protocol      = "tcp"
      }
    ]

    environment = [
      for k, v in var.environment_variables : {
        name  = k
        value = v
      }
    ]

    secrets = var.secrets

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.log_group_name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = var.service_name
      }
    }
  }
}

resource "aws_ecs_task_definition" "service" {
  family                   = "${var.project}-${var.environment}-${var.service_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([local.container_definition])

  tags = merge(var.tags, {
    Name    = "${var.project}-${var.environment}-${var.service_name}"
    Service = var.service_name
  })
}

resource "aws_ecs_service" "service" {
  name            = "${var.project}-${var.environment}-${var.service_name}"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Allow Terraform to update the task definition without replacing the service
  force_new_deployment = true

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = var.assign_public_ip
  }

  dynamic "load_balancer" {
    for_each = var.enable_load_balancer ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.service_name
      container_port   = var.container_port
    }
  }

  health_check_grace_period_seconds = var.enable_load_balancer ? var.health_check_grace_period_seconds : null

  # Ignore task definition changes so that CI/CD pipelines can update images
  # without Terraform overwriting them on the next plan/apply.
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  tags = merge(var.tags, {
    Name    = "${var.project}-${var.environment}-${var.service_name}"
    Service = var.service_name
  })
}
