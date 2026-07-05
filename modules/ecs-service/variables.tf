variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "cluster_id" {
  description = "ECS cluster ID"
  type        = string
}

variable "service_name" {
  description = "Name of the ECS service"
  type        = string
}

variable "container_image" {
  description = "Docker image URI for the container"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "CPU units for the task (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory in MB for the task"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of running tasks"
  type        = number
  default     = 1
}

variable "execution_role_arn" {
  description = "ARN of the ECS task execution IAM role"
  type        = string
}

variable "task_role_arn" {
  description = "ARN of the ECS task IAM role"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ECS service"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for the ECS service"
  type        = list(string)
}

variable "assign_public_ip" {
  description = "Assign a public IP to the task (required without NAT Gateway)"
  type        = bool
  default     = true
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}

variable "environment_variables" {
  description = "Map of environment variables to pass to the container"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "List of secrets from Secrets Manager to inject into the container"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

variable "enable_load_balancer" {
  description = "Whether to attach this service to a load balancer"
  type        = bool
  default     = false
}

variable "target_group_arn" {
  description = "ARN of the ALB target group (required when enable_load_balancer = true)"
  type        = string
  default     = ""
}

variable "health_check_grace_period_seconds" {
  description = "Grace period for health checks after deployment"
  type        = number
  default     = 60
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
