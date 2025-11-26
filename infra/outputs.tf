output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "ecr_validator_repository_url" {
  description = "URL of the validator service ECR repository"
  value       = aws_ecr_repository.validator_service.repository_url
}

output "ecr_uploader_repository_url" {
  description = "URL of the uploader service ECR repository"
  value       = aws_ecr_repository.uploader_service.repository_url
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.messages.id
}

output "sqs_queue_url" {
  description = "URL of the SQS queue"
  value       = aws_sqs_queue.messages.url
}

output "api_token" {
  description = "API token for testing (sensitive)"
  value       = random_password.api_token.result
  sensitive   = true
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "validator_service_name" {
  description = "Name of the validator ECS service"
  value       = aws_ecs_service.validator_service.name
}

output "uploader_service_name" {
  description = "Name of the uploader ECS service"
  value       = aws_ecs_service.uploader_service.name
}
