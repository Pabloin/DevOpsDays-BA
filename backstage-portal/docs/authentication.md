# Authentication

## User Login (GitHub OAuth)

Users sign in with their GitHub account. The OAuth app is registered at
[github.com/settings/applications](https://github.com/settings/applications).

**Callback URL**: `https://backstage.glaciar.org/api/auth/github/handler/frame`

### Sign-in resolver

The `usernameMatchingUserEntityName` resolver maps the GitHub username to a
Backstage `User` entity. Your GitHub username must exist in `examples/org.yaml`
for login to succeed.

Current users in `org.yaml`:

| GitHub username | Group |
|---|---|
| `Pabloin` | guests |
| `PabloEze` | guests |

To add a new user, add an entry to `examples/org.yaml` and redeploy.

## GitHub Integration (Scaffolder)

The Backstage backend uses a GitHub Personal Access Token (PAT) to:
- Create repositories when scaffolder templates run
- Read `catalog-info.yaml` files from GitHub repos

The PAT is stored in AWS Secrets Manager and injected as `GITHUB_TOKEN`.

**Required PAT scopes**: `repo`

> **Why not OIDC?** OIDC only works for GitHub Actions workflows. The Backstage
> backend is a long-running service in ECS — it needs a persistent credential
> to call the GitHub API at any time, not just during a CI/CD run.

## CI/CD (GitHub Actions OIDC)

The deployment pipeline authenticates to AWS using OpenID Connect — no AWS
credentials stored in GitHub.

The IAM role `backstage-mvp-github-actions-role` trusts tokens issued for:
```
repo:Pabloin/DevOpsDays-BA:ref:refs/heads/main
```

The only GitHub secret required is `AWS_ROLE_ARN`.
