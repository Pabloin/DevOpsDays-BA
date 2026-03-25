output "role_arn" {
  description = "ARN of the GitHub Actions IAM role — store as AWS_ROLE_ARN GitHub secret"
  value       = aws_iam_role.github_actions.arn
}
