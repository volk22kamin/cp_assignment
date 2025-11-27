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
│   ├── backend-s3/           # S3 backend for Terraform state (stores state locally)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── locals.tf
│   │   └── outputs.tf
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

**Note on State Locking**: This setup does not use DynamoDB for state locking. Since this is a single-developer environment with no automated Terraform runs in the CI/CD pipeline, state locking is not necessary. In a production environment with multiple developers or automated Terraform deployments, DynamoDB state locking should be added to prevent concurrent state modifications.

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

## Monitoring

### Access Monitoring Tools

**Grafana Dashboard:**

```bash
# Get Grafana URL
terraform output grafana_url

# Get admin password
terraform output -raw grafana_admin_password

# Access at: http://<ALB_DNS>/grafana
# Username: admin
```

**Prometheus:**

```bash
# Get Prometheus URL
terraform output prometheus_url

# Access at: http://<PROMETHEUS_ALB_DNS>
```

### Import Dashboards

1. **Prometheus Self-Monitoring** (Recommended):

   - In Grafana: Dashboards → Import
   - Enter ID: `3662`
   - Select Prometheus datasource
   - Shows: Prometheus health, performance, metrics

2. **Custom Infrastructure Dashboard**:

   - In Grafana: Dashboards → Import
   - Upload: `infra/files/dashboards/infrastructure-overview.json`

3. **AWS Services** (Optional - requires CloudWatch Exporter):
   - ECS Monitoring: ID `7362`
   - ALB Monitoring: ID `11074`
   - SQS Monitoring: ID `584`

See `infra/files/dashboards/README.md` for detailed monitoring setup guide.

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
