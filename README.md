# CP Assignment - DevOps Home Exam

This project implements a microservices architecture on AWS using ECS, demonstrating CI/CD practices with GitHub Actions and Infrastructure as Code with Terraform.

## Architecture Overview

The system consists of:

- **Validator Service**: REST API that validates tokens and payloads, then sends messages to SQS
- **Uploader Service**: Worker that polls SQS and uploads messages to S3
- **Infrastructure**: VPC, ECS Fargate, Application Load Balancer, SQS, S3, SSM Parameter Store

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured with `CHECKPOINT` profile
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

## Deployment Steps

### 1. Initialize and Deploy Infrastructure

```bash
cd infra
terraform init
terraform plan
terraform apply
```

After deployment, note the outputs:

- `alb_dns_name`: Load balancer endpoint
- `ecr_validator_repository_url`: ECR repo for validator service
- `ecr_uploader_repository_url`: ECR repo for uploader service
- `api_token`: Token for API authentication (run `terraform output -raw api_token`)

### 2. Build and Push Docker Images

```bash
# Get ECR login
aws ecr get-login-password --region us-east-1 --profile CHECKPOINT | docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

# Build and push validator service
cd app/validator-service
docker build -t <ECR_VALIDATOR_URL>:latest .
docker push <ECR_VALIDATOR_URL>:latest

# Build and push uploader service
cd ../uploader-service
docker build -t <ECR_UPLOADER_URL>:latest .
docker push <ECR_UPLOADER_URL>:latest
```

### 3. Update ECS Services

```bash
aws ecs update-service --cluster cp-assignment-cluster --service cp-assignment-validator-service --force-new-deployment --profile CHECKPOINT
aws ecs update-service --cluster cp-assignment-cluster --service cp-assignment-uploader-service --force-new-deployment --profile CHECKPOINT
```

### 4. Configure GitHub Secrets

For CI/CD to work, add these secrets to your GitHub repository:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

## Testing

### Test Validator Service

```bash
# Get the API token
TOKEN=$(cd infra && terraform output -raw api_token)

# Get ALB DNS
ALB_DNS=$(cd infra && terraform output -raw alb_dns_name)

# Valid request
curl -X POST http://$ALB_DNS/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "field1": "value1",
    "field2": "value2",
    "field3": "value3",
    "field4": "value4"
  }'

# Invalid token
curl -X POST http://$ALB_DNS/ \
  -H "Authorization: Bearer invalid-token" \
  -H "Content-Type: application/json" \
  -d '{
    "field1": "value1",
    "field2": "value2",
    "field3": "value3",
    "field4": "value4"
  }'

# Invalid payload (only 3 fields)
curl -X POST http://$ALB_DNS/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "field1": "value1",
    "field2": "value2",
    "field3": "value3"
  }'
```

### Verify S3 Upload

```bash
# Check S3 bucket for uploaded messages
aws s3 ls s3://$(cd infra && terraform output -raw s3_bucket_name)/messages/ --recursive --profile CHECKPOINT
```

## CI/CD Pipeline

The GitHub Actions pipeline automatically:

1. **CI Job**: Builds and pushes Docker images to ECR on push to `main`
2. **CD Job**: Updates ECS services to deploy new images

## Cleanup

```bash
cd infra
terraform destroy
```

## Architecture Decisions

- **Public Subnets**: ECS tasks run in public subnets with public IPs to avoid NAT Gateway costs
- **Fargate**: Serverless container execution for simplicity
- **SSM Parameter Store**: Secure token storage
- **SQS Long Polling**: Efficient message retrieval
- **CloudWatch Logs**: Centralized logging for both services

## Security Considerations

- S3 bucket has public access blocked
- Security groups restrict traffic appropriately
- IAM roles follow least privilege principle
- API token stored securely in SSM Parameter Store
- Secrets managed via GitHub Secrets for CI/CD
