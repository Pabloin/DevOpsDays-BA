locals {
  tags = {
    Environment = var.environment
    Project     = var.project
  }
}

# GitHub Actions OIDC provider
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # Thumbprint for token.actions.githubusercontent.com
  # See: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc_verify-thumbprint.html
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = merge(local.tags, { Name = "github-actions-oidc" })
}

# Trust policy: allow GitHub Actions to assume this role via OIDC
data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project}-${var.environment}-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json

  tags = merge(local.tags, { Name = "${var.project}-${var.environment}-github-actions-role" })
}

# Least-privilege permissions for the pipeline
data "aws_iam_policy_document" "github_actions_permissions" {
  # ECR auth token (must be resource *)
  statement {
    sid       = "ECRAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # ECR push to specific repo
  statement {
    sid    = "ECRPush"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = [var.ecr_repository_arn]
  }

  # ECS task definition actions (must be resource *)
  statement {
    sid    = "ECSRegisterTaskDef"
    effect = "Allow"
    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
    ]
    resources = ["*"]
  }

  # ECS deployment actions scoped to cluster and service
  statement {
    sid    = "ECSDeployment"
    effect = "Allow"
    actions = [
      "ecs:DescribeServices",
      "ecs:UpdateService",
    ]
    resources = [var.ecs_cluster_arn, var.ecs_service_arn]
  }

  # PassRole scoped to ECS execution and task roles
  statement {
    sid       = "PassExecutionRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [var.ecs_execution_role_arn, var.ecs_task_role_arn]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "github-actions-pipeline-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_permissions.json
}
