# Reflection Test Guide

## Overview

The reflection test validates that specs 12–13 (shared ECS environments + service deployment) are fully functional. It's an automated end-to-end validation that:

1. ✅ Verifies GitHub org (`mvp-glaciar-org`) is accessible
2. ✅ Checks AWS infrastructure (ECS clusters, ALBs, Route53)
3. ✅ Validates DNS wildcards work
4. ✅ Confirms scaffolder template is correct
5. ✅ **Deploys a real test service** to `dev` environment
6. ✅ Tests API endpoints (health, chat, Bedrock)
7. ✅ Cleans up all test artifacts

**Total runtime**: ~19 minutes

---

## Prerequisites

Before running the test, ensure:

### 1. AWS Credentials Configured
```bash
# Verify AWS_PROFILE=chile works
aws sts get-caller-identity --profile chile --region us-east-1
```

### 2. GitHub CLI Authenticated
```bash
# Verify gh is logged in to mvp-glaciar-org
gh auth status
gh repo list mvp-glaciar-org
```

### 3. Terraform Initialized
```bash
cd terraform/
terraform init
terraform output -json | jq '.' > /dev/null  # Should work without error
```

### 4. Required Tools Installed
```bash
# All of these must be available
command -v aws      # AWS CLI
command -v gh       # GitHub CLI
command -v terraform
command -v curl
command -v nslookup
command -v dig
command -v jq
command -v yq       # For YAML validation
```

---

## Running the Test

### Option 1: Full Test (Default)
Deploys a test service, validates it, then cleans up:

```bash
cd .kiro/specs/14-environment-reflection/test
./reflection-test.sh
```

**Duration**: ~19 minutes  
**Cleanup**: Automatic (removes test repo and ECS service)

### Option 2: Dry Run (Safe)
Validates everything except actual deployment:

```bash
./reflection-test.sh --dry-run
```

**Duration**: ~5 minutes  
**Cleanup**: None (no test artifacts created)

### Option 3: Manual Cleanup
Run the test but keep artifacts for inspection:

```bash
./reflection-test.sh --no-cleanup
```

**Duration**: ~14 minutes (skips cleanup phase)  
**Cleanup**: Manual (see cleanup instructions below)

---

## What the Test Does

### Phase 1: GitHub Organization (2 min)
- ✅ Verifies `gh` CLI works
- ✅ Checks GitHub authentication
- ✅ Lists repos in `mvp-glaciar-org`
- ✅ Verifies PAT has correct scopes
- ✅ Cleans up any stale test repos from prior runs

### Phase 2: AWS Infrastructure (3 min)
- ✅ Queries Terraform outputs
- ✅ Verifies ECS clusters exist (`backstage-apps-dev`, `backstage-apps-prod`)
- ✅ Checks ALBs are configured
- ✅ Confirms HTTPS listeners on port 443

### Phase 3: Route53 DNS (2 min)
- ✅ Queries Route53 hosted zone
- ✅ Verifies wildcard records (`*.dev.backstage.glaciar.org`, `*.prod.backstage.glaciar.org`)
- ✅ Tests DNS resolution
- ✅ Confirms ALB responds to HTTPS requests (404 expected)

### Phase 4: Scaffolder Template (1 min)
- ✅ Validates template YAML syntax
- ✅ Verifies form fields exist (service_name, deploy_to_ecs, ecs_environment)
- ✅ Confirms `github:actions:dispatch` references `deploy-service.yml`

### Phase 5: Service Deployment (8 min)
- ✅ Creates `test-reflection-ai` repo in `mvp-glaciar-org`
- ✅ Commits initial code
- ✅ Triggers `deploy-service.yml` workflow
- ✅ Waits for workflow to complete (timeout: 10m)
- ✅ Waits for ECS service to reach "running" state (timeout: 5m)
- ✅ Tests DNS resolution for `test-reflection-ai.dev.backstage.glaciar.org`
- ✅ Tests HTTPS endpoint (should return 200 or 404)
- ✅ Tests `/api/health` endpoint
- ✅ Tests `/api/chat` endpoint with Bedrock

### Phase 6: Cleanup (3 min)
- ✅ Scales down ECS service
- ✅ Deletes test repository
- ✅ Generates report

---

## Output

### Console Output
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Phase 1: GitHub Organization Validation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ GitHub CLI installed
✅ GitHub authenticated
✅ mvp-glaciar-org has repos
✅ PAT has repo scope
✅ No stale test repos found
...
```

### Log File
Detailed output is saved to:
```
.kiro/specs/14-environment-reflection/test/reflection-test.log
```

### Report File
Summary report is generated at:
```
REFLECTION_TEST_REPORT.md
```

Example:
```markdown
# Environment Reflection Test Report
**Date**: 2026-04-07 14:23:45

## Summary
- **Overall Status**: ✅ PASS
- **Duration**: 19m 34s
- **Total Tests**: 24
- **Passed**: 24
- **Failed**: 0

## Phases Executed
- [x] Phase 1: GitHub Organization Validation
- [x] Phase 2: AWS Infrastructure Validation
- [x] Phase 3: Route53 DNS Validation
- [x] Phase 4: Scaffolder Template Validation
- [x] Phase 5: Service Deployment Test
- [x] Phase 6: Cleanup & Report

## Next Steps
✅ Platform is ready for DevOpsDays demo!
```

---

## Troubleshooting

### Test Fails at Phase 1 (GitHub)
**Error**: `GitHub CLI not installed` or `Not authenticated`

**Fix**:
```bash
# Install GitHub CLI
brew install gh

# Authenticate
gh auth login
gh auth status
```

---

### Test Fails at Phase 2 (AWS Infrastructure)
**Error**: `Terraform output not accessible`

**Fix**:
```bash
cd terraform/
terraform init
terraform apply  # Re-apply if outputs changed
terraform output -json
```

**Error**: `AWS credentials not configured`

**Fix**:
```bash
# Verify AWS_PROFILE=chile works
aws sts get-caller-identity --profile chile --region us-east-1

# If not, configure credentials
aws configure --profile chile
```

---

### Test Fails at Phase 3 (DNS)
**Error**: `DNS resolution fails`

**Fix**:
```bash
# Verify Route53 zone exists
aws route53 list-hosted-zones --profile chile

# Verify wildcard records exist
aws route53 list-resource-record-sets \
  --hosted-zone-id <ZONE_ID> \
  --profile chile | grep -A5 "*.dev.backstage.glaciar.org"

# Test manual DNS resolution
nslookup test.dev.glaciar.org
dig test.dev.glaciar.org
```

---

### Test Fails at Phase 5 (Deployment)
**Error**: `Workflow times out`

**Fix**:
```bash
# Check workflow status
gh workflow list --repo Pabloin/DevOpsDays-BA

# Check recent runs
gh run list --repo Pabloin/DevOpsDays-BA --limit 5

# View logs of failed run
gh run view <RUN_ID> --log --repo Pabloin/DevOpsDays-BA
```

**Error**: `ECS service does not reach running state`

**Fix**:
```bash
# Check CloudWatch logs
aws logs tail /ecs/backstage-apps-dev/test-reflection-ai-dev --follow \
  --profile chile --region us-east-1

# Check task definition
aws ecs describe-task-definition \
  --task-definition test-reflection-ai-dev \
  --profile chile --region us-east-1

# Check service status
aws ecs describe-services \
  --cluster backstage-apps-dev \
  --services test-reflection-ai-dev \
  --profile chile --region us-east-1 \
  --query 'services[0].{status: status, runningCount: runningCount, events: events[0:3]}'
```

---

## Manual Cleanup

If the test fails or is interrupted, manually clean up:

```bash
# 1. Delete test repo
gh repo delete mvp-glaciar-org/test-reflection-ai --confirm

# 2. Scale down ECS service
aws ecs update-service \
  --cluster backstage-apps-dev \
  --service test-reflection-ai-dev \
  --desired-count 0 \
  --profile chile --region us-east-1

# 3. Wait for stabilization
aws ecs wait services-stable \
  --cluster backstage-apps-dev \
  --services test-reflection-ai-dev \
  --profile chile --region us-east-1

# 4. Verify cleanup
aws ecs describe-services \
  --cluster backstage-apps-dev \
  --services test-reflection-ai-dev \
  --profile chile --region us-east-1
```

---

## Re-running the Test

The test is **idempotent** — it's safe to run multiple times:

```bash
# Run test again
./reflection-test.sh

# It will:
# 1. Clean up stale test repos from prior runs
# 2. Reuse or recreate test repo
# 3. Deploy new version of test service
# 4. Validate everything works
# 5. Clean up again
```

---

## Understanding Results

### ✅ All Phases Pass
```
✅ Reflection test completed successfully
```

**Meaning**: Your platform is ready for the DevOpsDays BA talk! All infrastructure, templates, and workflows are functioning correctly.

**Next steps**: 
- Merge spec 13 branch if not already done
- Deploy Backstage portal (CI/CD handles it)
- Prepare demo scripts

---

### ❌ Some Tests Fail
```
❌ Reflection test completed with failures
Failed tests:
  - ECS service is running (running count: $running)
  - Health check returns JSON
```

**Meaning**: One or more components are not working. Check the error message and troubleshooting guide above.

**Next steps**:
1. Review the error message
2. Check the log file: `reflection-test.log`
3. Follow troubleshooting guide for that phase
4. Fix the issue
5. Re-run: `./reflection-test.sh`

---

## Advanced Usage

### View Real-Time Logs While Test Runs
In another terminal:
```bash
tail -f .kiro/specs/14-environment-reflection/test/reflection-test.log
```

---

### Run Only Specific Phases (Advanced)
Edit the script or run phases manually. For example, to run only Phase 3:
```bash
cd .kiro/specs/14-environment-reflection
source ./reflection-test.sh
phase_3_dns_validation
```

---

## Next Steps After Successful Test

1. **Merge Spec 13 to main** (if not already done)
   ```bash
   gh pr create --title "feat: deploy service to ECS (spec 13)" ...
   gh pr merge <PR_URL>
   ```

2. **Deploy Backstage Portal**
   - Push to main (CI/CD triggers automatically)
   - Verify deployment at `https://backstage.glaciar.org`

3. **Prepare Demo**
   - Scaffold a service with ECS deploy
   - Show app live at `https://<service>.dev.backstage.glaciar.org`
   - Demonstrate Bedrock integration

4. **Document Results**
   - Save `REFLECTION_TEST_REPORT.md` for reference
   - Include in presentation notes

---

## Questions?

If you encounter issues:
1. Check the logs: `cat reflection-test.log | tail -100`
2. Check the report: `cat REFLECTION_TEST_REPORT.md`
3. Review troubleshooting section above
4. Check CloudWatch logs for ECS tasks
5. Verify AWS credentials and GitHub authentication
