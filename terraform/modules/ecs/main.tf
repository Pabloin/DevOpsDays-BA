locals {
  tags = {
    Environment = var.environment
    Project     = var.project
  }
  name_prefix           = "${var.project}-${var.environment}"
  ecs_security_group_id = var.ecs_security_group_id
}

# ─── IAM: Task Execution Role ────────────────────────────────────────────────

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${local.name_prefix}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = merge(local.tags, { Name = "${local.name_prefix}-ecs-execution-role" })
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "secrets_access" {
  statement {
    sid     = "AllowSecretsAccess"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      var.rds_secret_arn,
      var.github_secret_arn,
    ]
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  name   = "secrets-access"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.secrets_access.json
}

# ─── IAM: Task Role ──────────────────────────────────────────────────────────

resource "aws_iam_role" "task" {
  name               = "${local.name_prefix}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json

  tags = merge(local.tags, { Name = "${local.name_prefix}-ecs-task-role" })
}

data "aws_iam_policy_document" "route53_access" {
  statement {
    sid = "AllowRoute53RecordManagement"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:GetHostedZone",
      "route53:ListResourceRecordSets",
    ]
    resources = [var.route53_hosted_zone_arn]
  }
}

resource "aws_iam_role_policy" "task_route53" {
  name   = "route53-dns-management"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.route53_access.json
}

# ─── Security Group (passed in from root to avoid circular dep with RDS) ─────
# The ECS SG is created in the root module so RDS can reference it without
# creating a module dependency cycle (RDS needs ECS SG, ECS needs RDS endpoint).

# ─── CloudWatch Log Group ─────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = 30

  tags = merge(local.tags, { Name = "/ecs/${local.name_prefix}" })
}

# ─── ECS Cluster ─────────────────────────────────────────────────────────────

resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  tags = merge(local.tags, { Name = "${local.name_prefix}-cluster" })
}

# ─── ECS Task Definition ─────────────────────────────────────────────────────

resource "aws_ecs_task_definition" "main" {
  family                   = "${local.name_prefix}-backstage"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "backstage"
      image     = "${var.ecr_repository_url}:${var.image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = 7007
          protocol      = "tcp"
        }
      ]

      secrets = [
        {
          name      = "POSTGRES_HOST"
          valueFrom = "${var.rds_secret_arn}:host::"
        },
        {
          name      = "POSTGRES_PORT"
          valueFrom = "${var.rds_secret_arn}:port::"
        },
        {
          name      = "POSTGRES_USER"
          valueFrom = "${var.rds_secret_arn}:username::"
        },
        {
          name      = "POSTGRES_PASSWORD"
          valueFrom = "${var.rds_secret_arn}:password::"
        },
        {
          name      = "AUTH_GITHUB_CLIENT_ID"
          valueFrom = "${var.github_secret_arn}:AUTH_GITHUB_CLIENT_ID::"
        },
        {
          name      = "AUTH_GITHUB_CLIENT_SECRET"
          valueFrom = "${var.github_secret_arn}:AUTH_GITHUB_CLIENT_SECRET::"
        },
        {
          name      = "GITHUB_TOKEN"
          valueFrom = "${var.github_secret_arn}:GITHUB_TOKEN::"
        }
      ]

      environment = [
        {
          name  = "NODE_ENV"
          value = "production"
        },
        {
          name  = "PGSSLMODE"
          value = "require"
        },
        {
          name  = "APP_BASE_URL"
          value = var.app_base_url
        },
        {
          name  = "ROUTE53_HOSTED_ZONE_ID"
          value = var.route53_hosted_zone_id
        },
        {
          name  = "ROUTE53_DOMAIN_NAME"
          value = var.route53_domain_name
        },
        {
          name  = "ALB_DNS_NAME"
          value = var.alb_dns_name
        },
        {
          name  = "ALB_HOSTED_ZONE_ID"
          value = var.alb_hosted_zone_id
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.main.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "backstage"
        }
      }
    }
  ])

  tags = merge(local.tags, { Name = "${local.name_prefix}-backstage" })
}

data "aws_region" "current" {}

# ─── ECS Service ─────────────────────────────────────────────────────────────

resource "aws_ecs_service" "main" {
  name            = "${local.name_prefix}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [local.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "backstage"
    container_port   = 7007
  }

  depends_on = [aws_iam_role_policy_attachment.execution_managed]

  tags = merge(local.tags, { Name = "${local.name_prefix}-service" })
}
