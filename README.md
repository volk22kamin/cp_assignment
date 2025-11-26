# CP Assignment - DevOps Home Exam

This project implements a microservices architecture on AWS using ECS, demonstrating CI/CD practices with GitHub Actions and Infrastructure as Code with Terraform.

## Architecture Overview

The system consists of:

- **Validator Service**: REST API that validates tokens and payloads, then sends messages to SQS
- **Uploader Service**: Worker that polls SQS and uploads messages to S3
- **Infrastructure**: VPC, ECS Fargate, Application Load Balancer, SQS, S3, SSM Parameter Store

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured with `CHECKPOINT` profile (credentials stored in `~/.aws/credentials`)
- Terraform >= 1.0
- Docker
- Git

## Project Structure

```
.
├── app/
│   ├── validator-service/    # REST API service
│   │   ├── app.py
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   └── uploader-service/     # SQS to S3 worker
│       ├── app.py
│       ├── Dockerfile
│       └── requirements.txt
├── infra/                    # Terraform infrastructure
│   ├── provider.tf
│   ├── variables.tf
│   ├── network.tf
│   ├── storage.tf
│   ├── ecr.tf
│   ├── iam.tf
│   ├── ecs_tasks.tf
│   ├── alb.tf
│   ├── ecs_services.tf
│   └── outputs.tf
└── .github/
    └── workflows/
        └── pipeline.yml      # CI/CD pipeline
```

## Infrastructure State Management

This project uses a two-tier Terraform state management approach:

1. **Backend S3 Module** (`infra/backend-s3/`): Creates the S3 bucket for storing Terraform state. This module itself stores its state **locally** in `infra/backend-s3/terraform.tfstate`.
2. **Main Infrastructure** (`infra/`): Uses the S3 backend created by the backend-s3 module to store its state remotely.

### Initial Setup

First, create the S3 backend bucket:

```bash
cd infra/backend-s3
terraform init
terraform apply
```

Then deploy the main infrastructure:

```bash
cd ..
terraform init
terraform apply
```

## Deployment Steps

### 1. Deploy Infrastructure

After the initial setup above, you can deploy or update the infrastructure:

```bash
cd infra
terraform plan
terraform apply
```

After deployment, note the outputs:

- `alb_dns_name`: Load balancer endpoint
- `ecr_validator_repository_url`: ECR repo for validator service
- `ecr_uploader_repository_url`: ECR repo for uploader service
- `api_token`: Token for API authentication (run `terraform output -raw api_token`)

### 2. Configure GitHub Secrets

For CI/CD to work, add these secrets to your GitHub repository:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

**Note**: Docker images are **not** uploaded manually to ECR. The CI/CD pipeline automatically builds and pushes images when changes are pushed to the `main` branch.

## Testing

### Test Validator Service

```bash
# Get the API token
TOKEN=$(cd infra && terraform output -raw api_token)

# Get ALB DNS
ALB_DNS=$(cd infra && terraform output -raw alb_dns_name)

# Valid request (token in body)
curl -X POST http://$ALB_DNS/ \
  -H "Content-Type: application/json" \
  -d '{
    "token": "'$TOKEN'",
    "data": {
      "field1": "value1",
      "field2": "value2",
      "field3": "value3",
      "field4": "value4"
    }
  }'

# Invalid token
curl -X POST http://$ALB_DNS/ \
  -H "Content-Type: application/json" \
  -d '{
    "token": "invalid-token",
    "data": {
      "field1": "value1",
      "field2": "value2",
      "field3": "value3",
      "field4": "value4"
    }
  }'

# Invalid payload (only 3 fields)
curl -X POST http://$ALB_DNS/ \
  -H "Content-Type: application/json" \
  -d '{
    "token": "'$TOKEN'",
    "data": {
      "field1": "value1",
      "field2": "value2",
      "field3": "value3"
    }
  }'
```

### Verify S3 Upload

```bash
# Check S3 bucket for uploaded messages
aws s3 ls s3://$(cd infra && terraform output -raw s3_bucket_name)/messages/ --recursive --profile CHECKPOINT
```

## CI/CD Pipeline

The GitHub Actions pipeline automatically handles all Docker image builds and deployments:

1. **Changes Detection**: Detects which services changed (validator or uploader)
2. **Build and Push**: Builds Docker images and pushes them to ECR (triggered on push to `main` or `dev` branches)
3. **Deploy**: Updates ECS services to deploy new images

**Important**: Docker images are **only** uploaded to ECR through the CI/CD pipeline, not manually. The pipeline is triggered when:

- Changes are pushed to the `app/` directory
- Changes are made to the pipeline configuration
- Manual workflow dispatch is triggered

## Cleanup

```bash
cd infra
terraform destroy
```

## Architecture Decisions

- **Public Subnets**: ECS tasks run in public subnets with public IPs to avoid NAT Gateway costs, Could also be achieved with private subnets and VPC Endpoints.
- **Fargate**: Serverless container execution for simplicity
- **SSM Parameter Store**: Secure token storage
- **SQS Long Polling**: Efficient message retrieval
- **CloudWatch Logs**: Centralized logging for both services

## Security Considerations

- Security groups restrict traffic appropriately
- IAM roles follow least privilege principle
- API token stored securely in SSM Parameter Store
- Secrets managed via GitHub Secrets for CI/CD
- S3 bucket versioning enabled for state management and message storage
