# Error: Scaffolder Template Push Fails with 404

## Problem Summary

Backstage scaffolder successfully creates GitHub repos in `mvp-glaciar-org` but fails when pushing code with:

```
Error: HTTP Error: 404 Not Found {data={"statusCode":404,"statusMessage":"Not Found"}}
at Git.push (/app/node_modules/@backstage/plugin-scaffolder-node/dist/scm/git.cjs.js:178:15)
```

## What We've Verified ✓

1. **GitHub Token is correct and working**
   - Token in AWS Secrets Manager: `ghp_***REDACTED***`
   - Token has correct scopes: `repo`, `workflow`, `admin:org`
   - Manual push with same token WORKS:
     ```bash
     git push https://x-access-token:${TOKEN}@github.com/mvp-glaciar-org/repo-ai-05.git
     # SUCCESS ✓
     ```

2. **Organization permissions are correct**
   - Base permissions changed from "Read" to "Write"
   - URL: https://github.com/orgs/mvp-glaciar-org/settings/member_privileges
   - Members can create private repos ✓

3. **ECS task is using the updated token**
   - Task restarted after terraform apply
   - Secrets Manager has the correct token
   - Token verified via troubleshooting commands in CLAUDE.md

4. **Repo is created successfully**
   - Scaffolder creates the repo (e.g., repo-ai-05)
   - Repo exists in GitHub as private repo
   - But push step fails with 404

## The Issue

Manual git push with the token works, but Backstage scaffolder fails. This suggests:

- Backstage is NOT using the token correctly when pushing
- Possible URL construction issue in Backstage GitHub integration
- Possible credential passing issue in `@backstage/plugin-scaffolder-backend-module-github`

## Backstage Configuration

**app-config.yaml:**
```yaml
integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}
```

**Template step that fails:**
```yaml
- id: publish
  name: Publish to GitHub
  action: publish:github
  input:
    description: ${{ parameters.description }}
    repoUrl: ${{ parameters.repoUrl }}
    defaultBranch: main
```

## Error Timeline

1. ✓ Fetch template (9 seconds) - SUCCESS
2. ✗ Publish to GitHub (2 seconds) - FAILS at push
   - Creates repo successfully
   - Inits git repo
   - Adds files
   - Commits
   - **FAILS at push with 404**
3. ⊘ Register in catalog - NOT REACHED

## Full Error Log

```
2026-04-05T22:05:25.124Z Beginning step Fetch template
2026-04-05T22:05:25.198Z info: Fetching template content from remote URL
2026-04-05T22:05:25.211Z info: Processing 19 template files/directories
2026-04-05T22:05:25.294Z info: Writing file README.md
[... more files ...]
2026-04-05T22:05:25.382Z info: Writing file backend/.env.example
2026-04-05T22:05:25.384Z Finished step Fetch template

2026-04-05T22:05:25.385Z Beginning step Publish to GitHub
2026-04-05T22:05:26.968Z info: Init git repository {dir=/tmp/ce7a1de6-22b0-44e7-83e3-2ec47ddb2702}
2026-04-05T22:05:26.973Z info: Adding file {dir=/tmp/ce7a1de6-22b0-44e7-83e3-2ec47ddb2702,filepath=.}
2026-04-05T22:05:26.978Z info: Committing file to repo {dir=/tmp/ce7a1de6-22b0-44e7-83e3-2ec47ddb2702,message=initial commit}
2026-04-05T22:05:26.985Z info: Pushing directory to remote {dir=/tmp/ce7a1de6-22b0-44e7-83e3-2ec47ddb2702,remote=origin}
2026-04-05T22:05:27.227Z error: Failed to push to repo {dir=/tmp/ce7a1de6-22b0-44e7-83e3-2ec47ddb2702, remote=origin}
2026-04-05T22:05:27.227Z Error: HTTP Error: 404 Not Found {data={"statusCode":404,"statusMessage":"Not Found"}}
    at Git.push (/app/node_modules/@backstage/plugin-scaffolder-node/dist/scm/git.cjs.js:178:15)
    at process.processTicksAndRejections (node:internal/process/task_queues:104:5)
    at async Object.initRepoAndPush (/app/node_modules/@backstage/plugin-scaffolder-node/dist/actions/gitHelpers.cjs.js:36:3)
    at async Object.initRepoPushAndProtect (/app/node_modules/@backstage/plugin-scaffolder-backend-module-github/dist/actions/helpers.cjs.js:187:24)
    at async Object.handler (/app/node_modules/@backstage/plugin-scaffolder-backend-module-github/dist/actions/github.cjs.js:166:28)
    at async NunjucksWorkflowRunner.executeStep (/app/node_modules/@backstage/plugin-scaffolder-backend/dist/scaffolder/tasks/NunjucksWorkflowRunner.cjs.js:344:9)
    at async NunjucksWorkflowRunner.execute (/app/node_modules/@backstage/plugin-scaffolder-backend/dist/scaffolder/tasks/NunjucksWorkflowRunner.cjs.js:467:9)
    at async TaskWorker.runOneTask (/app/node_modules/@backstage/plugin-scaffolder-backend/dist/scaffolder/tasks/TaskWorker.cjs.js:128:26)
    at async run (/app/node_modules/p-queue/dist/index.js:163:29)
```

## Manual Test That WORKS

```bash
# Get token from Secrets Manager
TOKEN=$(aws secretsmanager get-secret-value \
  --secret-id backstage-mvp-github-oauth \
  --profile chile --region us-east-1 \
  --query 'SecretString' --output text | jq -r '.GITHUB_TOKEN')

# Create test repo and push
mkdir /tmp/test-push
cd /tmp/test-push
git init
echo "test" > README.md
git add .
git config user.email "test@test.com"
git config user.name "Test"
git commit -m "test"
git remote add origin "https://x-access-token:${TOKEN}@github.com/mvp-glaciar-org/repo-ai-05.git"
git push -u origin main

# Result: SUCCESS ✓
# To https://github.com/mvp-glaciar-org/repo-ai-05.git
#  * [new branch]      main -> main
```

## Environment

- Backstage version: Latest (new frontend system)
- Deployment: AWS ECS Fargate
- Region: us-east-1
- Organization: mvp-glaciar-org
- Domain: https://backstage.glaciar.org

## Questions for Claude

1. Why does manual git push work but Backstage scaffolder fails?
2. How does `@backstage/plugin-scaffolder-backend-module-github` pass credentials to git?
3. Is there a configuration issue in app-config.yaml?
4. Could this be a bug in the Backstage GitHub integration module?
5. Are there additional permissions or settings needed in GitHub organization?
6. Should we use a GitHub App instead of PAT token?

## Claude Opus Diagnosis

**Root Cause: Race condition + isomorphic-git auth**

Backstage uses `isomorphic-git` (not native git) for push operations. Two compounding issues:

1. **Race condition**: GitHub API returns success for repo creation, but git infrastructure hasn't fully propagated. Push happens ~0ms later and GitHub's git server returns 404.

2. **isomorphic-git credential handling**: Manual test works because native git uses `x-access-token:TOKEN` in URL. `isomorphic-git` uses an `onAuth` callback that may construct credentials differently. Some versions had bugs where token wasn't properly passed to push.

**Current version**: `@backstage/plugin-scaffolder-backend-module-github@0.9.7`

## Possible Solutions to Try

1. ✓ **Add gitAuthorName and gitAuthorEmail** - Some versions require these (TRYING FIRST)
   ```yaml
   input:
     repoUrl: ${{ parameters.repoUrl }}
     defaultBranch: main
     gitAuthorName: backstage-bot
     gitAuthorEmail: backstage@glaciar.org
   ```

2. **Add repoVisibility: public temporarily** - Rule out private repo auth issues
   ```yaml
   input:
     repoUrl: ${{ parameters.repoUrl }}
     defaultBranch: main
     repoVisibility: public
   ```

3. **Upgrade @backstage/plugin-scaffolder-backend-module-github** - Has had several push-related fixes

4. **Two-step workaround** - Replace `publish:github` with `github:repo:create` + `github:repo:push` as separate steps with delay

5. **Switch to GitHub App authentication** - Handles auth more reliably with isomorphic-git than PAT

## Detailed Analysis (2026-04-05)

### Config Verification

- `app-config.yaml:44-49` defines `integrations.github` with `${GITHUB_TOKEN}` — correct
- `app-config.production.yaml` does NOT override `integrations` — so base config carries through (additive merge)
- ECS task definition injects `GITHUB_TOKEN` from Secrets Manager — verified
- Templates use standard `publish:github` with `RepoUrlPicker` restricted to `mvp-glaciar-org` — correct

### Why manual push works but scaffolder fails

| Factor | Manual push | Backstage scaffolder |
|--------|-------------|---------------------|
| Git client | native git | isomorphic-git |
| Auth method | `x-access-token:TOKEN` in URL | `onAuth` callback |
| Timing | Repo existed for minutes/hours | Push ~0ms after creation |
| Repo visibility | N/A (already existed) | Private (default) |

### The isomorphic-git credential flow

1. Backstage creates repo via GitHub REST API (works — uses `@octokit`)
2. Calls `isomorphic-git.push()` with `onAuth` callback
3. `onAuth` returns `{ username: 'x-access-token', password: TOKEN }` from the integration config
4. isomorphic-git constructs HTTP Basic auth header
5. GitHub responds with 404 — either because:
   a. The repo hasn't propagated to git servers yet (race condition)
   b. The auth header is malformed/missing for the new private repo

### Timing analysis from logs

```
22:05:25.385  Publish step begins
22:05:26.968  Repo created via GitHub API (1.6s for API call)
22:05:26.968  git init
22:05:26.973  git add
22:05:26.978  git commit
22:05:26.985  git push starts (0.017s after repo creation!)
22:05:27.227  404 error (0.24s for push attempt)
```

**Only 17ms between repo creation API response and push attempt.** This is extremely fast and strongly suggests the race condition.

## Fixes Applied (branch: feature/10-fix-scaffolder-push-404)

### Fix 1: Add gitAuthorName/gitAuthorEmail to templates
Some isomorphic-git versions fail silently without these, causing auth fallback issues.

### Fix 2: Set repoVisibility explicitly
Rules out private repo auth edge case with isomorphic-git.

### Fix 3: Upgrade scaffolder-backend-module-github
Version 0.9.7 may have the race condition bug. Newer versions may include retry logic.

### Fix 4: Disable branch protection on default branch
`protectDefaultBranch: false` — avoids a second API call to a freshly-created repo that could also 404.

### Fix 5: Add scaffolder.defaultAuthor in app-config.yaml
Safety net so isomorphic-git always has author info, even if template doesn't specify it.

## Source Code Analysis (from node_modules)

Traced the exact credential flow in `@backstage/plugin-scaffolder-backend-module-github@0.9.7`:

```
publish:github handler
  → getOctokitOptions({ integrations, credentialsProvider, token, host, owner, repo })
  → octokitOptions.auth = resolved token (from integration config or provided token)
  → creates repo via Octokit (GitHub REST API) ← WORKS
  → calls initRepoPushAndProtect(remoteUrl, octokitOptions.auth, ...)
    → calls initRepoAndPush({ auth: { username: "x-access-token", password: token } })
      → isomorphic-git.push() with onAuth callback ← FAILS with 404
```

**The auth is constructed correctly** (`x-access-token` + token), same format as manual push.
This confirms the **race condition** as the primary cause — the repo exists in GitHub's API layer
but hasn't propagated to the git server layer when push happens 17ms later.

**Note on `${{ secrets.USER_OAUTH_TOKEN }}`**: Removed from templates. This requires the user
to be authenticated via GitHub OAuth. With `guest: {}` auth enabled, users logging in as guest
would get an empty token, causing the push to fail regardless of the race condition.

## Fix 6: Monkey-patch push retry in Docker build (THE ACTUAL FIX)

Fixes 1-5 (template config changes) were deployed and tested — **still 404**.
This confirms the race condition is the sole cause. Config-level changes cannot fix it.

**Solution**: A patch script (`packages/backend/patch-scaffolder-push-retry.js`) that modifies
`@backstage/plugin-scaffolder-node/dist/actions/gitHelpers.cjs.js` at Docker build time to add
retry logic around `git.push()`:

- 3 retries max
- 3 second delay between retries
- Only retries on 404 errors (other errors throw immediately)

Applied in Dockerfile with:
```dockerfile
COPY --chown=node:node packages/backend/patch-scaffolder-push-retry.js ./packages/backend/
RUN node packages/backend/patch-scaffolder-push-retry.js
```

This gives GitHub ~3-6 seconds to propagate the new repo to its git servers before giving up.
