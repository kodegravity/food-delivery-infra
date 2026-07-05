locals {
  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  # ECR image URIs — placeholder until first CI/CD push.
  # After pushing real images, ECS services pick them up automatically.
  ecr_image = {
    for svc in var.service_names :
    svc => "${module.ecr.repository_urls[svc]}:latest"
  }
}

# ── VPC ──────────────────────────────────────────────────────────────────────

module "vpc" {
  source = "../../modules/vpc"

  project              = var.project
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  tags                 = local.tags
}

# ── ECR ──────────────────────────────────────────────────────────────────────

module "ecr" {
  source = "../../modules/ecr"

  project       = var.project
  environment   = var.environment
  service_names = var.service_names
  tags          = local.tags
}

# ── Security Groups ───────────────────────────────────────────────────────────

module "security_groups" {
  source = "../../modules/security-groups"

  project     = var.project
  environment = var.environment
  vpc_id      = module.vpc.vpc_id
  tags        = local.tags
}

# ── RDS PostgreSQL ────────────────────────────────────────────────────────────
# Placed in private subnets — not accessible from the internet.

module "rds" {
  source = "../../modules/rds"

  project            = var.project
  environment        = var.environment
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.rds_sg_id]
  db_name            = var.db_name
  db_username        = var.db_username
  instance_class     = var.db_instance_class
  allocated_storage  = var.db_allocated_storage
  postgres_version   = var.postgres_version
  tags               = local.tags
}

# ── IAM ──────────────────────────────────────────────────────────────────────

module "iam" {
  source = "../../modules/iam"

  project       = var.project
  environment   = var.environment
  db_secret_arn = module.rds.secret_arn
  tags          = local.tags
}

# ── CloudWatch Log Groups ─────────────────────────────────────────────────────

module "cloudwatch" {
  source = "../../modules/cloudwatch"

  project        = var.project
  environment    = var.environment
  service_names  = var.service_names
  retention_days = var.log_retention_days
  tags           = local.tags
}

# ── ALB ──────────────────────────────────────────────────────────────────────

module "alb" {
  source = "../../modules/alb"

  project           = var.project
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.public_subnet_ids
  security_group_id = module.security_groups.alb_sg_id
  target_port       = var.container_port
  tags              = local.tags
}

# ── ECS Cluster ───────────────────────────────────────────────────────────────

module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  project                   = var.project
  environment               = var.environment
  enable_container_insights = false
  tags                      = local.tags
}

# ── ECS Services ──────────────────────────────────────────────────────────────
# All services run in public subnets with assign_public_ip = true so they can
# pull images from ECR without a NAT Gateway (saves ~$32/month per gateway).
# Security groups restrict all inbound traffic to the expected sources only.

module "ecs_api_gateway" {
  source = "../../modules/ecs-service"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region
  cluster_id  = module.ecs_cluster.cluster_id

  service_name    = "api-gateway"
  container_image = local.ecr_image["api-gateway"]
  container_port  = var.container_port
  cpu             = var.task_cpu
  memory          = var.task_memory
  desired_count   = var.desired_count

  execution_role_arn = module.iam.execution_role_arn
  task_role_arn      = module.iam.task_role_arn

  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = [module.security_groups.api_gateway_sg_id]
  assign_public_ip   = true

  log_group_name = module.cloudwatch.log_group_names["api-gateway"]

  environment_variables = {
    SPRING_PROFILES_ACTIVE = "dev"
    SERVER_PORT            = tostring(var.container_port)
    USER_SERVICE_URL       = "http://${module.ecs_user_service.service_name}:${var.container_port}"
    RESTAURANT_SERVICE_URL = "http://${module.ecs_restaurant_service.service_name}:${var.container_port}"
    ORDER_SERVICE_URL      = "http://${module.ecs_order_service.service_name}:${var.container_port}"
  }

  # api-gateway is attached to the ALB
  enable_load_balancer = true
  target_group_arn     = module.alb.target_group_arn

  tags = local.tags

  depends_on = [module.alb]
}

module "ecs_user_service" {
  source = "../../modules/ecs-service"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region
  cluster_id  = module.ecs_cluster.cluster_id

  service_name    = "user-service"
  container_image = local.ecr_image["user-service"]
  container_port  = var.container_port
  cpu             = var.task_cpu
  memory          = var.task_memory
  desired_count   = var.desired_count

  execution_role_arn = module.iam.execution_role_arn
  task_role_arn      = module.iam.task_role_arn

  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = [module.security_groups.backend_services_sg_id]
  assign_public_ip   = true

  log_group_name = module.cloudwatch.log_group_names["user-service"]

  environment_variables = {
    SPRING_PROFILES_ACTIVE = "dev"
    SERVER_PORT            = tostring(var.container_port)
    DB_HOST                = module.rds.address
    DB_PORT                = tostring(module.rds.port)
    DB_NAME                = module.rds.db_name
  }

  secrets = [
    {
      name      = "DB_USERNAME"
      valueFrom = "${module.rds.secret_arn}:username::"
    },
    {
      name      = "DB_PASSWORD"
      valueFrom = "${module.rds.secret_arn}:password::"
    }
  ]

  enable_load_balancer = false

  tags = local.tags
}

module "ecs_restaurant_service" {
  source = "../../modules/ecs-service"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region
  cluster_id  = module.ecs_cluster.cluster_id

  service_name    = "restaurant-service"
  container_image = local.ecr_image["restaurant-service"]
  container_port  = var.container_port
  cpu             = var.task_cpu
  memory          = var.task_memory
  desired_count   = var.desired_count

  execution_role_arn = module.iam.execution_role_arn
  task_role_arn      = module.iam.task_role_arn

  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = [module.security_groups.backend_services_sg_id]
  assign_public_ip   = true

  log_group_name = module.cloudwatch.log_group_names["restaurant-service"]

  environment_variables = {
    SPRING_PROFILES_ACTIVE = "dev"
    SERVER_PORT            = tostring(var.container_port)
    DB_HOST                = module.rds.address
    DB_PORT                = tostring(module.rds.port)
    DB_NAME                = module.rds.db_name
  }

  secrets = [
    {
      name      = "DB_USERNAME"
      valueFrom = "${module.rds.secret_arn}:username::"
    },
    {
      name      = "DB_PASSWORD"
      valueFrom = "${module.rds.secret_arn}:password::"
    }
  ]

  enable_load_balancer = false

  tags = local.tags
}

module "ecs_order_service" {
  source = "../../modules/ecs-service"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region
  cluster_id  = module.ecs_cluster.cluster_id

  service_name    = "order-service"
  container_image = local.ecr_image["order-service"]
  container_port  = var.container_port
  cpu             = var.task_cpu
  memory          = var.task_memory
  desired_count   = var.desired_count

  execution_role_arn = module.iam.execution_role_arn
  task_role_arn      = module.iam.task_role_arn

  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = [module.security_groups.backend_services_sg_id]
  assign_public_ip   = true

  log_group_name = module.cloudwatch.log_group_names["order-service"]

  environment_variables = {
    SPRING_PROFILES_ACTIVE = "dev"
    SERVER_PORT            = tostring(var.container_port)
    DB_HOST                = module.rds.address
    DB_PORT                = tostring(module.rds.port)
    DB_NAME                = module.rds.db_name
  }

  secrets = [
    {
      name      = "DB_USERNAME"
      valueFrom = "${module.rds.secret_arn}:username::"
    },
    {
      name      = "DB_PASSWORD"
      valueFrom = "${module.rds.secret_arn}:password::"
    }
  ]

  enable_load_balancer = false

  tags = local.tags
}
