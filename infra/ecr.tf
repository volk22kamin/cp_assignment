# ECR Repositories
resource "aws_ecr_repository" "validator_service" {
  name                 = "${var.project_name}/validator-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-validator-service"
  }
}

resource "aws_ecr_repository" "uploader_service" {
  name                 = "${var.project_name}/uploader-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-uploader-service"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "validator_service" {
  name              = "/ecs/${var.project_name}/validator-service"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-validator-service-logs"
  }
}

resource "aws_cloudwatch_log_group" "uploader_service" {
  name              = "/ecs/${var.project_name}/uploader-service"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-uploader-service-logs"
  }
}
