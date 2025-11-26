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

# Prometheus Task Definition
resource "aws_ecs_task_definition" "prometheus" {
  family                   = "${var.project_name}-prometheus"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.prometheus_task.arn

  # Using ephemeral storage instead of EFS for simplicity
  # Data will be lost on container restart, but acceptable for dev/demo
  volume {
    name = "prometheus-data"
  }

  volume {
    name = "prometheus-config"
  }

  container_definitions = jsonencode([
    {
      name  = "prometheus"
      image = "prom/prometheus:latest"

      portMappings = [
        {
          containerPort = 9090
          protocol      = "tcp"
        }
      ]

      command = [
        "--config.file=/etc/prometheus/prometheus.yml",
        "--storage.tsdb.path=/prometheus",
        "--web.console.libraries=/usr/share/prometheus/console_libraries",
        "--web.console.templates=/usr/share/prometheus/consoles",
        "--web.enable-lifecycle",
        "--web.external-url=/prometheus"
      ]

      mountPoints = [
        {
          sourceVolume  = "prometheus-data"
          containerPath = "/prometheus"
          readOnly      = false
        }
      ]

      environment = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.prometheus.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:9090/-/healthy || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    },
    {
      name      = "prometheus-config-sidecar"
      image     = "busybox:latest"
      essential = false

      command = [
        "sh",
        "-c",
        <<-EOT
          cat > /etc/prometheus/prometheus.yml << 'EOF'
          ${file("${path.module}/files/prometheus.yml")}
          EOF
          cat > /etc/prometheus/alerts.yml << 'EOF'
          ${file("${path.module}/files/prometheus-alerts.yml")}
          EOF
          sleep infinity
        EOT
      ]

      mountPoints = [
        {
          sourceVolume  = "prometheus-config"
          containerPath = "/etc/prometheus"
          readOnly      = false
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.prometheus.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "config-sidecar"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-prometheus"
  }
}

# Grafana Task Definition
resource "aws_ecs_task_definition" "grafana" {
  family                   = "${var.project_name}-grafana"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.grafana_task.arn

  container_definitions = jsonencode([
    {
      name  = "grafana"
      image = "grafana/grafana:latest"

      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "GF_SERVER_ROOT_URL"
          value = "%(protocol)s://%(domain)s:%(http_port)s/grafana/"
        },
        {
          name  = "GF_SERVER_SERVE_FROM_SUB_PATH"
          value = "true"
        },
        {
          name  = "GF_SECURITY_ADMIN_USER"
          value = "admin"
        },
        {
          name  = "GF_AUTH_ANONYMOUS_ENABLED"
          value = "false"
        }
      ]

      secrets = [
        {
          name      = "GF_SECURITY_ADMIN_PASSWORD"
          valueFrom = aws_ssm_parameter.grafana_admin_password.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.grafana.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-grafana"
  }
}

