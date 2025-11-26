# S3 Bucket
resource "aws_s3_bucket" "messages" {
  bucket_prefix = "${var.project_name}-messages-"

  tags = {
    Name = "${var.project_name}-messages"
  }
}

resource "aws_s3_bucket_versioning" "messages" {
  bucket = aws_s3_bucket.messages.id

  versioning_configuration {
    status = "Enabled"
  }
}

# SQS Queue
resource "aws_sqs_queue" "messages" {
  name                       = "${var.project_name}-messages"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400 # 1 day
  receive_wait_time_seconds  = 20    # Long polling

  tags = {
    Name = "${var.project_name}-messages"
  }
}

# Generate random token
resource "random_password" "api_token" {
  length  = 32
  special = true
}

# SSM Parameter for token
resource "aws_ssm_parameter" "api_token" {
  name        = "/app/token"
  description = "API token for validator service"
  type        = "SecureString"
  value       = random_password.api_token.result

  tags = {
    Name = "${var.project_name}-api-token"
  }
}
