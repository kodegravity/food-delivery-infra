variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-2"
}

variable "project" {
  description = "Project name used as a prefix for all resources"
  type        = string
  default     = "food-delivery"
}

variable "environment" {
  description = "Environment name (dev / qa / prod)"
  type        = string
  default     = "dev"
}

# ── VPC ──────────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the two public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the two private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "availability_zones" {
  description = "Availability zones for subnets (must have at least 2)"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
}

# ── ECR ──────────────────────────────────────────────────────────────────────

variable "service_names" {
  description = "List of microservice names (used for ECR repos, ECS services, log groups)"
  type        = list(string)
  default     = ["api-gateway", "user-service", "restaurant-service", "order-service"]
}

# ── RDS ──────────────────────────────────────────────────────────────────────

variable "db_name" {
  description = "Initial PostgreSQL database name"
  type        = string
  default     = "fooddelivery"
}

variable "db_username" {
  description = "Master username for RDS"
  type        = string
  default     = "fooddelivery"
}

variable "db_instance_class" {
  description = "RDS instance type"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "RDS storage in GB"
  type        = number
  default     = 20
}

variable "postgres_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.3"
}

# ── ECS ──────────────────────────────────────────────────────────────────────

variable "task_cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory in MB"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of running task instances per service"
  type        = number
  default     = 1
}

variable "container_port" {
  description = "Port Spring Boot services listen on"
  type        = number
  default     = 8080
}

# ── CloudWatch ───────────────────────────────────────────────────────────────

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
}
