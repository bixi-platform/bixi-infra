# ECS Fargate + ALB for the Go REST API.
# Provisioned only when enable_ecs = true.

resource "aws_ecs_cluster" "main" {
  count = var.enable_ecs ? 1 : 0
  name  = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "api" {
  count             = var.enable_ecs ? 1 : 0
  name              = "/ecs/${local.name_prefix}-api"
  retention_in_days = 14
}

resource "aws_ecs_task_definition" "api" {
  count                    = var.enable_ecs ? 1 : 0
  family                   = "${local.name_prefix}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.api_cpu
  memory                   = var.api_memory_mb
  execution_role_arn       = aws_iam_role.ecs_task_execution[0].arn
  task_role_arn            = aws_iam_role.ecs_task[0].arn

  container_definitions = jsonencode([{
    name      = "api"
    image     = var.api_image
    essential = true

    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]

    environment = [
      { name = "DATABASE_URL", value = local.resolved_database_url },
      { name = "PORT", value = "8080" },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.api[0].name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "api"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "wget -qO- http://localhost:8080/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 10
    }
  }])
}

# ── Security groups ───────────────────────────────────────────────────────────

resource "aws_security_group" "alb" {
  count       = var.enable_ecs ? 1 : 0
  name        = "${local.name_prefix}-alb"
  description = "Public HTTP/HTTPS to the ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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

resource "aws_security_group" "api_task" {
  count       = var.enable_ecs ? 1 : 0
  name        = "${local.name_prefix}-api-task"
  description = "Allow ALB to reach the API container on 8080"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb[0].id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── ALB ───────────────────────────────────────────────────────────────────────

resource "aws_lb" "api" {
  count              = var.enable_ecs ? 1 : 0
  name               = "${local.name_prefix}-api"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb[0].id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "api" {
  count       = var.enable_ecs ? 1 : 0
  name        = "${local.name_prefix}-api"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
}

resource "aws_lb_listener" "api_http" {
  count             = var.enable_ecs ? 1 : 0
  load_balancer_arn = aws_lb.api[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api[0].arn
  }
}

# ── ECS Service ───────────────────────────────────────────────────────────────

resource "aws_ecs_service" "api" {
  count           = var.enable_ecs ? 1 : 0
  name            = "${local.name_prefix}-api"
  cluster         = aws_ecs_cluster.main[0].id
  task_definition = aws_ecs_task_definition.api[0].arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.api_task[0].id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api[0].arn
    container_name   = "api"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.api_http]
}
