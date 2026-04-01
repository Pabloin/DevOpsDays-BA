# Claude Code Instructions

## Git workflow

- Always work on a feature branch (never commit directly to `main`)
- When merging to main, **create a PR** — never `git merge` directly
- Use `gh pr create` to open the PR, then share the URL with the user
- Branch naming: `feature/<spec-number>-<short-description>`

## Terraform

- Always run from `terraform/` directory
- Source credentials before apply: `source .env.prod && AWS_PROFILE=chile terraform apply`
- Never commit `terraform.tfvars` or `.env*` files

## AWS

- Always use `--profile chile` for AWS CLI commands
- Region: `us-east-1`

## Specs

- Follow the Kiro spec-driven approach: create spec first (requirements + design + tasks), implement after
- Update task checkboxes in `tasks.md` as work completes
- Spec directory: `.kiro/specs/<number>-<name>/`
