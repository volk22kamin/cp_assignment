# Validator Service Task Definition
resource "aws_ecs_task_definition" "validator_service" {
  family                   = "${var.project_name}-validator-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.validator_service_cpu
  memory                   = var.validator_service_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.validator_task.arn

  container_definitions = jsonencode([
    {
      name  = "validator-service"
      image = "${aws_ecr_repository.validator_service.repository_url}:latest"

      portMappings = [
        {
          containerPort = var.validator_service_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "SSM_TOKEN_PARAMETER"
          value = aws_ssm_parameter.api_token.name
        },
        {
          name  = "SQS_QUEUE_URL"
          value = aws_sqs_queue.messages.url
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.validator_service.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.validator_service_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-validator-service"
  }
}

# Uploader Service Task Definition
resource "aws_ecs_task_definition" "uploader_service" {
  family                   = "${var.project_name}-uploader-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.uploader_service_cpu
  memory                   = var.uploader_service_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.uploader_task.arn

  container_definitions = jsonencode([
    {
      name  = "uploader-service"
      image = "${aws_ecr_repository.uploader_service.repository_url}:latest"

      environment = [
        {
          name  = "SQS_QUEUE_URL"
          value = aws_sqs_queue.messages.url
        },
        {
          name  = "S3_BUCKET_NAME"
          value = aws_s3_bucket.messages.id
        },
        {
          name  = "POLL_INTERVAL"
          value = tostring(var.poll_interval)
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.uploader_service.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-uploader-service"
  }
}
