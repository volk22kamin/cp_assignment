# Validator Service
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

  health_check_grace_period_seconds = 60

  depends_on = [
    aws_lb_listener.http
  ]

  tags = {
    Name = "${var.project_name}-validator-service"
  }
}

# Uploader Service
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

  tags = {
    Name = "${var.project_name}-uploader-service"
  }
}
