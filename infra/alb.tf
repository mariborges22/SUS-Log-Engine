# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${var.project_name}-alb-${var.environment}"
  }
}

# Target Groups
# Target Groups
data "aws_lb_target_group" "frontend" {
  name = "${var.project_name}-front-tg-${var.environment}"
}

# resource "aws_lb_target_group" "frontend" {
#   name        = "${var.project_name}-front-tg-${var.environment}"
#   port        = 80
#   protocol    = "HTTP"
#   vpc_id      = data.aws_vpc.existing_prod.id
#   target_type = "ip"
# 
#   health_check {
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#     timeout             = 3
#     interval            = 30
#     path                = "/"
#     port                = "80"
#     protocol            = "HTTP"
#     matcher             = "200"
#   }
# 
#   lifecycle {
#     create_before_destroy = true
#   }
# }

resource "aws_lb_target_group" "api" {
  name        = "${var.project_name}-api-tg-${var.environment}"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.existing_prod.id
  target_type = "ip"

  health_check {
    path                = "/api/health"
    port                = "traffic-port"
    matcher             = "200-399"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

# ==============================================================================
# LISTENERS
# HTTP listener: forward (sem HTTPS) ou redirect (com HTTPS)
# ==============================================================================

# Listener HTTP/80 — Se tiver certificado, redireciona para HTTPS
resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Sem HTTPS: forward direto
  dynamic "default_action" {
    for_each = var.acm_certificate_arn == "" ? [1] : []
    content {
      type             = "forward"
      target_group_arn = data.aws_lb_target_group.frontend.arn
    }
  }

  # Com HTTPS: redirect 80 → 443
  dynamic "default_action" {
    for_each = var.acm_certificate_arn != "" ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }
}

# Listener HTTPS/443 — Criado somente se certificado ACM for fornecido
resource "aws_lb_listener" "https" {
  count             = var.acm_certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = data.aws_lb_target_group.frontend.arn
  }
}

# Listener Rule: /api* → API target group
# Usa o listener HTTPS se existir, senão o HTTP
resource "aws_lb_listener_rule" "api" {
  listener_arn = var.acm_certificate_arn != "" ? aws_lb_listener.https[0].arn : aws_lb_listener.frontend.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    path_pattern {
      values = ["/api*"]
    }
  }
}

# ==============================================================================
# SECURITY GROUP FOR ALB
# ==============================================================================
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg-${var.environment}"
  description = "ALB Public Access"
  vpc_id      = data.aws_vpc.existing_prod.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
