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
│   ├── validator-service/         # REST API service
│   │   ├── app.py                 # Flask app with Prometheus metrics
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   └── uploader-service/          # SQS to S3 worker
│       ├── app.py                 # Worker with Prometheus metrics
│       ├── Dockerfile
│       └── requirements.txt
├── infra/                         # Terraform infrastructure
│   ├── backend-s3/                # S3 backend for Terraform state (stores state locally)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── locals.tf
│   │   └── outputs.tf
│   ├── files/                     # Configuration files for monitoring
│   │   ├── prometheus.yml         # Prometheus config with service discovery
│   │   ├── prometheus-alerts.yml  # Alert rules for Prometheus
│   │   ├── grafana-datasource.yml # Grafana datasource configuration
│   │   ├── grafana-dashboard-provider.yml
│   │   ├── validator-dashboard.json    # Custom Validator dashboard
│   │   └── uploader-dashboard.json     # Custom Uploader dashboard
│   ├── provider.tf
│   ├── variables.tf
│   ├── network.tf                 # VPC, subnets, security groups
│   ├── storage.tf                 # S3 bucket, SQS queue
│   ├── ecr.tf                     # ECR repositories
│   ├── iam.tf                     # IAM roles and policies
│   ├── ecs_tasks.tf               # ECS task definitions (app + monitoring)
│   ├── alb.tf                     # Application Load Balancers (main + monitoring)
│   ├── ecs_services.tf            # ECS services
│   ├── monitoring.tf              # Service discovery namespace
│   └── outputs.tf
└── .github/
    └── workflows/
        ├── validator-pipeline.yml # CI/CD for validator service
        └── uploader-pipeline.yml  # CI/CD for uploader service
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

This project includes a comprehensive monitoring solution using **Prometheus** and **Grafana** deployed on ECS Fargate.

### Architecture

**Separate Load Balancers:**

- **Main ALB**: Serves the validator service and Grafana at `/grafana`
- **Monitoring ALB**: Dedicated ALB for Prometheus at the root path

The decision to use a separate ALB for Prometheus was made to avoid subpath routing complexity. Prometheus has limited support for running under a subpath, which can cause issues with its web UI and API endpoints. Using a dedicated ALB simplifies the configuration and ensures reliable access to Prometheus.

### Service Discovery

Prometheus is configured to automatically discover and scrape metrics from the microservices using **AWS Cloud Map (Service Discovery)**:

- Both validator and uploader services register with AWS Cloud Map
- Prometheus uses the `ec2_sd_config` with DNS-based service discovery
- Metrics are automatically scraped from discovered service instances
- No manual configuration needed when services scale up or down

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

### Custom Dashboards

The project includes **two custom Grafana dashboards** specifically designed to monitor the application services:

1. **Validator Service Dashboard** (`infra/files/dashboards/validator-dashboard.json`):

   - HTTP request rates and response times
   - Token validation success/failure rates
   - SQS message publishing metrics
   - Error rates and status code distribution

2. **Uploader Service Dashboard** (`infra/files/dashboards/uploader-dashboard.json`):
   - SQS polling and message processing rates
   - S3 upload success/failure metrics
   - Processing latency and throughput
   - Queue depth and message age

**Automatic Dashboard Provisioning:**

Dashboards are automatically provisioned from JSON files in the `infra/files/` directory. To add new dashboards:

1. Place your dashboard JSON file in `infra/files/`
2. The dashboard will be automatically loaded when Grafana starts
3. No manual import needed - Grafana is configured to scan this directory

**Manual Datasource Configuration:**

> [!NOTE]
> After Grafana starts, you need to **manually configure the Prometheus datasource URL** in the Grafana GUI:
>
> 1. Log into Grafana
> 2. Navigate to **Configuration** → **Data Sources** → **Prometheus**
> 3. Update the URL field with the Prometheus DNS (get it from `terraform output prometheus_url`)
> 4. Click **Save & Test** to verify the connection
>
> This manual step is required because the Prometheus ALB DNS is dynamically generated and cannot be pre-configured in the datasource YAML file.

### Alerts

Alert rules are configured in Prometheus (`infra/files/prometheus/alerts.yml`) to monitor critical metrics:

- High error rates in validator service
- SQS message processing failures
- Service availability issues
- Resource utilization thresholds

**Note**: Alert rules are defined and loaded into Prometheus, but **no alert notification channels** (e.g., email, Slack, PagerDuty) are configured. This means alerts will be visible in the Prometheus UI and Grafana, but they won't trigger external notifications. In a production environment, you would configure Alertmanager with appropriate notification receivers.

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

### SSM Parameter Store Best Practice

> [!IMPORTANT] > **SSM Parameter and Terraform State**: In this implementation, the API token is created and managed by Terraform in `infra/ecs_tasks.tf`. While this works for demonstration purposes, **in a production environment, the SSM parameter should be created manually (outside of Terraform)** to avoid storing the sensitive token value in the Terraform state file.
>
> **Recommended approach for production:**
>
> 1. Create the SSM parameter manually using AWS CLI or Console:
>    ```bash
>    aws ssm put-parameter \
>      --name "/cp-assignment/api-token" \
>      --value "your-secure-token-here" \
>      --type "SecureString" \
>      --profile CHECKPOINT
>    ```
> 2. Reference the existing parameter in Terraform using a `data` source instead of creating it with `aws_ssm_parameter` resource
> 3. This ensures the sensitive token value never appears in the Terraform state file
>
> The current implementation prioritizes simplicity for the assignment, but be aware of this security consideration when adapting this code for production use.
