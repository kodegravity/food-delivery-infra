# food-delivery-infra

AWS Terraform infrastructure for the **Food Delivery** microservices platform.  
Currently provisioned: **dev** environment only.

---

## Architecture Overview

```
Internet
   │  HTTP :80
   ▼
┌──────────────────────────────────────────────┐
│  Application Load Balancer  (public subnets) │
└──────────────┬───────────────────────────────┘
               │ :8080
               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Public Subnets  (ECS Fargate — assign_public_ip = true, no NAT GW)    │
│                                                                         │
│  ┌────────────┐   ┌──────────────┐   ┌──────────────────┐   ┌────────┐ │
│  │ api-gateway│──▶│ user-service │   │restaurant-service│   │ order  │ │
│  └────────────┘   └──────────────┘   └──────────────────┘   └────────┘ │
└──────────────────────────────────────────────────────────────┬──────────┘
                                                               │ :5432
               ┌───────────────────────────────────────────────┘
               ▼
┌──────────────────────────────────────────────┐
│  Private Subnets                             │
│  RDS PostgreSQL  db.t4g.micro  (Single-AZ)  │
└──────────────────────────────────────────────┘
```

### Key cost decisions for dev
| Skipped (saves cost) | Why |
|---|---|
| NAT Gateway | ~$32/mo each — ECS tasks use `assign_public_ip` instead |
| Multi-AZ RDS | Single-AZ `db.t4g.micro` is sufficient for dev |
| MSK / Redis / Aurora | Not needed yet |
| Route53 / ACM / HTTPS | Use ALB DNS over HTTP for dev |
| Container Insights | Optional CloudWatch feature disabled by default |

---

## Repository Structure

```
food-delivery-infra/
├── environments/
│   └── dev/
│       ├── main.tf                   # Module wiring
│       ├── provider.tf               # AWS provider + Terraform version
│       ├── variables.tf              # Input variable declarations
│       ├── terraform.tfvars.example  # Safe-to-commit example values
│       └── outputs.tf                # Useful outputs after apply
└── modules/
    ├── vpc/                # VPC, subnets, IGW, route tables
    ├── ecr/                # ECR repositories + lifecycle policies
    ├── security-groups/    # ALB, api-gateway, backend, RDS SGs
    ├── iam/                # ECS execution role + task role
    ├── cloudwatch/         # CloudWatch log groups
    ├── rds/                # RDS PostgreSQL + Secrets Manager secret
    ├── alb/                # ALB, target group, HTTP listener
    ├── ecs-cluster/        # ECS Fargate cluster
    └── ecs-service/        # Reusable task definition + ECS service
```

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) ≥ 1.5
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with credentials
- [Docker](https://www.docker.com/get-started)
- IAM permissions: `AmazonECS_FullAccess`, `AmazonRDS_FullAccess`, `AmazonVPCFullAccess`, `AmazonEC2ContainerRegistryFullAccess`, `SecretsManagerReadWrite`, `IAMFullAccess`, `ElasticLoadBalancingFullAccess`, `CloudWatchLogsFullAccess`

---

## Getting Started

### 1. Configure variables

```bash
cd environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars if you need to change any defaults
```

### 2. Initialise Terraform

```bash
cd environments/dev
terraform init
```

### 3. Review the plan

```bash
terraform plan
```

### 4. Apply

```bash
terraform apply
```

> **Note:** RDS provisioning takes ~5–8 minutes. Total apply time is ~10–15 minutes.

After a successful apply, key outputs are printed:

```
alb_dns_name         = "http://food-delivery-dev-alb-XXXXX.us-east-2.elb.amazonaws.com"
ecr_repository_urls  = { "api-gateway" = "...", "user-service" = "...", ... }
rds_endpoint         = "food-delivery-dev-postgres.XXXX.us-east-2.rds.amazonaws.com:5432"
ecs_cluster_name     = "food-delivery-dev"
```

---

## Working with Docker & ECR

### Authenticate Docker with ECR

```bash
# Get the login command from Terraform output
terraform output -raw ecr_login_command | bash

# Or manually:
aws ecr get-login-password --region us-east-2 \
  | docker login --username AWS --password-stdin \
    <account-id>.dkr.ecr.us-east-2.amazonaws.com
```

### Build and push an image

```bash
# Set variables
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=us-east-2
SERVICE=user-service   # one of: api-gateway, user-service, restaurant-service, order-service
REPO="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/food-delivery/${SERVICE}"

# Build
docker build -t "${REPO}:latest" ./path/to/${SERVICE}

# Push
docker push "${REPO}:latest"
```

### Push all services

```bash
for SERVICE in api-gateway user-service restaurant-service order-service; do
  REPO="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/food-delivery/${SERVICE}"
  docker build -t "${REPO}:latest" ./${SERVICE}
  docker push "${REPO}:latest"
done
```

---

## Updating an ECS Service

After pushing a new image, force a new deployment so ECS pulls the latest tag:

```bash
CLUSTER=food-delivery-dev
REGION=us-east-2

# Update a single service
aws ecs update-service \
  --cluster "${CLUSTER}" \
  --service "food-delivery-dev-user-service" \
  --force-new-deployment \
  --region "${REGION}"

# Or update all services
for SVC in api-gateway user-service restaurant-service order-service; do
  aws ecs update-service \
    --cluster "${CLUSTER}" \
    --service "food-delivery-dev-${SVC}" \
    --force-new-deployment \
    --region "${REGION}"
done
```

### Check service status

```bash
aws ecs describe-services \
  --cluster food-delivery-dev \
  --services food-delivery-dev-api-gateway \
  --region us-east-2 \
  --query "services[0].{Status:status,Running:runningCount,Desired:desiredCount}"
```

---

## Reading Logs

```bash
# Stream logs for a service
aws logs tail /ecs/food-delivery/dev/user-service --follow --region us-east-2

# Query last 100 lines
aws logs tail /ecs/food-delivery/dev/order-service \
  --since 1h --region us-east-2
```

---

## Reading Database Credentials

Credentials are stored in Secrets Manager. You can view them without exposing them in your shell:

```bash
aws secretsmanager get-secret-value \
  --secret-id food-delivery/dev/db/credentials \
  --query SecretString \
  --output text \
  --region us-east-2 | python3 -m json.tool
```

---

## Approximate Monthly Cost (dev)

| Resource | Spec | Est. Cost/mo |
|---|---|---|
| ECS Fargate × 4 | 256 CPU / 512 MB × 1 task each | ~$12 |
| RDS PostgreSQL | db.t4g.micro, 20 GB gp2, Single-AZ | ~$15 |
| Application Load Balancer | 1 ALB, minimal traffic | ~$18 |
| ECR | 4 repos, ~1 GB storage | ~$0.40 |
| Secrets Manager | 1 secret | ~$0.40 |
| CloudWatch Logs | 7-day retention, low volume | ~$1 |
| **Total** | | **~$47/mo** |

> NAT Gateway is **not** provisioned — saves ~$32/month per AZ.

---

## Tearing Down

```bash
cd environments/dev
terraform destroy
```

> This will permanently delete all resources including the RDS database.  
> `skip_final_snapshot = true` and `deletion_protection = false` are set intentionally for dev.

---

## Roadmap (future environments)

- `environments/qa` — same topology, slightly larger instances
- `environments/prod` — Multi-AZ RDS, NAT Gateway, ACM + HTTPS, Route53, autoscaling
- MSK (Kafka) for async order events
- ElastiCache Redis for session caching
- AWS WAF on the ALB
