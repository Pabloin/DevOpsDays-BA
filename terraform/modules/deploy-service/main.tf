data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  # Stable name prefix — used across all resources
  name = "${var.service_name}-${var.environment}"

  # ALB target group names are max 32 chars
  tg_name = substr("${var.service_name}-${var.environment}-tg", 0, 32)

  # Service URL
  service_url = "https://${var.service_name}.${var.environment}.${var.base_domain}"

  # Stable ALB listener rule priority: hash of name → 1000–49999
  rule_priority = (tonumber(parseint(substr(sha256(local.name), 0, 4), 16)) % 48000) + 1000

  tags = {
    Environment = var.environment
    Project     = var.project
    Service     = var.service_name
    ManagedBy   = "terraform"
  }
}

# ─── ECR Repository ───────────────────────────────────────────────────────────

resource "aws_ecr_repository" "service" {
  name                 = local.name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = merge(local.tags, { Name = local.name })
}

resource "aws_ecr_lifecycle_policy" "service" {
  repository = aws_ecr_repository.service.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
}

# ─── IAM Roles ────────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Task execution role — allows ECS to pull image and write logs
resource "aws_iam_role" "execution" {
  name               = "${local.name}-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
  tags               = merge(local.tags, { Name = "${local.name}-exec-role" })
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task role — runtime permissions for the app (Bedrock)
resource "aws_iam_role" "task" {
  name               = "${local.name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
  tags               = merge(local.tags, { Name = "${local.name}-task-role" })
}

data "aws_iam_policy_document" "bedrock" {
  statement {
    sid    = "BedrockInvoke"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = [
      "arn:aws:bedrock:${var.aws_region}::foundation-model/*"
    ]
  }
}

resource "aws_iam_role_policy" "bedrock" {
  name   = "bedrock-invoke"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.bedrock.json
}

# ─── CloudWatch Log Group ────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "service" {
  name              = "/ecs/${local.name}"
  retention_in_days = 7
  tags              = local.tags
}

# ─── ECS Task Definition ─────────────────────────────────────────────────────

resource "aws_ecs_task_definition" "service" {
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name      = var.service_name
    image     = "${aws_ecr_repository.service.repository_url}:${var.image_tag}"
    essential = true

    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]

    environment = [
      { name = "PORT",              value = tostring(var.container_port) },
      { name = "BEDROCK_MODEL_ID",  value = var.bedrock_model_id },
      { name = "AWS_REGION",        value = var.aws_region },
      { name = "NODE_ENV",          value = "production" },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.service.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "ecs"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "wget -qO- http://localhost:${var.container_port}/api/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])

  tags = merge(local.tags, { Name = local.name })
}

# ─── Task Security Group ──────────────────────────────────────────────────────

resource "aws_security_group" "task" {
  name        = "${local.name}-task-sg"
  description = "Allow traffic from shared ALB to ${local.name} ECS task"
  vpc_id      = var.vpc_id

  ingress {
    description     = "App port from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${local.name}-task-sg" })
}

# ─── ALB Target Group ─────────────────────────────────────────────────────────

resource "aws_lb_target_group" "service" {
  name        = local.tg_name
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/api/health"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    matcher             = "200"
  }

  tags = merge(local.tags, { Name = local.tg_name })
}

# ─── ALB Listener Rule ────────────────────────────────────────────────────────

resource "aws_lb_listener_rule" "service" {
  listener_arn = var.alb_listener_arn
  priority     = local.rule_priority

  condition {
    host_header {
      values = ["${var.service_name}.${var.environment}.${var.base_domain}"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service.arn
  }

  tags = merge(local.tags, { Name = "${local.name}-rule" })
}

# ─── ECS Service ─────────────────────────────────────────────────────────────

resource "aws_ecs_service" "service" {
  name            = local.name
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.service.arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  # Allow external changes (e.g. image updates via force-new-deployment)
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  tags = merge(local.tags, { Name = local.name })
}
