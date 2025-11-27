resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "validator_service" {
  name        = "${var.project_name}-validator-tg"
  port        = var.validator_service_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-validator-tg"
  }
}



# Target Group for Grafana
resource "aws_lb_target_group" "grafana" {
  name        = "${var.project_name}-grafana-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/api/health"
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-grafana-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.validator_service.arn
  }
}



# Listener Rule for Grafana (path-based routing)
resource "aws_lb_listener_rule" "grafana" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 101

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }

  condition {
    path_pattern {
      values = ["/grafana*"]
    }
  }

  tags = {
    Name = "${var.project_name}-grafana-rule"
  }
}

# ============================================
# MONITORING ALB (Separate from Main ALB)
# ============================================

resource "aws_lb" "monitoring" {
  name               = "${var.project_name}-monitoring-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_monitoring.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${var.project_name}-monitoring-alb"
  }
}

# Target Group for Prometheus (on monitoring ALB, served at root)
resource "aws_lb_target_group" "prometheus_monitoring" {
  name        = "${var.project_name}-prom-mon-tg"
  port        = 9090
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/-/healthy"
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-prometheus-monitoring-tg"
  }
}

# Listener for Monitoring ALB - Prometheus at root
resource "aws_lb_listener" "monitoring_http" {
  load_balancer_arn = aws_lb.monitoring.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prometheus_monitoring.arn
  }
}
