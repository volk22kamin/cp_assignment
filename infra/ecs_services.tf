resource "aws_service_discovery_service" "validator_service" {
  name = "validator-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
  }
}

resource "aws_service_discovery_service" "uploader_service" {
  name = "uploader-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
  }
}

resource "aws_ecs_service" "validator_service" {
  name            = "${var.project_name}-validator-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.validator_service.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.validator_service.arn
    container_name   = "validator-service"
    container_port   = var.validator_service_port
  }

  service_registries {
    registry_arn = aws_service_discovery_service.validator_service.arn
  }

  health_check_grace_period_seconds = 60

  depends_on = [
    aws_lb_listener.http
  ]

  tags = {
    Name = "${var.project_name}-validator-service"
  }
}

resource "aws_ecs_service" "uploader_service" {
  name            = "${var.project_name}-uploader-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.uploader_service.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.uploader_service.arn
  }

  tags = {
    Name = "${var.project_name}-uploader-service"
  }
}

resource "aws_ecs_service" "prometheus" {
  name            = "${var.project_name}-prometheus"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.monitoring.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.prometheus_monitoring.arn
    container_name   = "prometheus"
    container_port   = 9090
  }

  health_check_grace_period_seconds = 120

  depends_on = [
    aws_lb_listener.monitoring_http
  ]

  tags = {
    Name = "${var.project_name}-prometheus"
  }
}

resource "aws_ecs_service" "grafana" {
  name            = "${var.project_name}-grafana"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.monitoring.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.grafana.arn
    container_name   = "grafana"
    container_port   = 3000
  }

  health_check_grace_period_seconds = 120

  depends_on = [
    aws_lb_listener_rule.grafana
  ]

  tags = {
    Name = "${var.project_name}-grafana"
  }
}

