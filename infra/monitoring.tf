resource "aws_security_group" "monitoring" {
  name_prefix = "${var.project_name}-monitoring-"
  description = "Security group for monitoring services"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_monitoring.id]
    description     = "Allow Prometheus access from Monitoring ALB"
  }

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Allow Grafana access from ALB"
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    self        = true
    description = "Allow Prometheus self-scraping"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.project_name}-monitoring-sg"
  }
}

resource "aws_cloudwatch_log_group" "prometheus" {
  name              = "/ecs/${var.project_name}/prometheus"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-prometheus-logs"
  }
}

resource "aws_cloudwatch_log_group" "grafana" {
  name              = "/ecs/${var.project_name}/grafana"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-grafana-logs"
  }
}

resource "random_password" "grafana_admin" {
  length  = 16
  special = true
}

resource "aws_ssm_parameter" "grafana_admin_password" {
  name        = "/${var.project_name}/grafana/admin-password"
  description = "Grafana admin password"
  type        = "SecureString"
  value       = random_password.grafana_admin.result

  tags = {
    Name = "${var.project_name}-grafana-admin-password"
  }
}
