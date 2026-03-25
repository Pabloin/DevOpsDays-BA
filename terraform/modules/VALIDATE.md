# Module Validation Checkpoint

Before applying, run `terraform validate` in each module directory and in the root `terraform/` directory to confirm there are no syntax errors.

```bash
# Validate each module
terraform -chdir=terraform/modules/vpc validate
terraform -chdir=terraform/modules/ecr validate
terraform -chdir=terraform/modules/secrets validate
terraform -chdir=terraform/modules/rds validate
terraform -chdir=terraform/modules/alb validate
terraform -chdir=terraform/modules/ecs validate

# Validate root module (after terraform init)
terraform -chdir=terraform validate
```

> Note: Module-level `validate` requires a `terraform init` in each directory first (or use `-chdir` from the repo root). The root module validate is the most important — it validates all modules together with their wiring.
