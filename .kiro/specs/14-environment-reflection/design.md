# Design: Environment Reflection & Testing (`14-environment-reflection`)

## Testing Architecture

```
User runs: ./scripts/reflection-test.sh
    ↓
Reflection Test Suite (automated, sequential)
    ├─ Phase 1: GitHub Organization Validation
    │   ├── List repos in mvp-glaciar-org
    │   ├── Verify PAT scopes
    │   └── Create/clean test repos
    │
    ├─ Phase 2: AWS Infrastructure Validation
    │   ├── Query Terraform outputs
    │   ├── Check ECS clusters exist
    │   ├── Validate security groups
    │   └── Verify ALB listeners
    │
    ├─ Phase 3: Route53 DNS Validation
    │   ├── Query wildcard records for dev/prod
    │   ├── Verify DNS resolution
    │   └── Test ALB HTTPS response
    │
    ├─ Phase 4: Scaffolder Template Validation
    │   ├── Load template YAML
    │   ├── Verify form fields
    │   └── Check GitHub Actions reference
    │
    ├─ Phase 5: Service Deployment Test
    │   ├── Create test-reflection-ai repo in org
    │   ├── Trigger deploy-service.yml workflow
    │   ├── Monitor workflow execution
    │   ├── Verify ECS service status
    │   ├── Test DNS resolution
    │   ├── Test HTTP/HTTPS endpoints
    │   └── Test Bedrock API call
    │
    └─ Phase 6: Cleanup & Report
        ├── Delete test ECS service
        ├── Remove test repo from org
        ├── Verify clean state
        └── Generate summary report
    ↓
Summary Report (pass/fail, timing, errors)
```

---

## Implementation Strategy

### Testing Tool: Bash + AWS CLI + curl

All tests run as bash scripts in `scripts/reflection-test.sh` with helper functions:

```bash
# Helper: check_pass / check_fail
check_pass "GitHub org has repos" $exit_code

# Helper: get_terraform_output
CLUSTER_ARN=$(get_terraform_output "ecs_dev_cluster_arn")

# Helper: wait_for_service
wait_for_service "backstage-apps-dev" "test-reflection-ai-dev"

# Helper: test_endpoint
test_endpoint "https://test-reflection-ai.dev.backstage.glaciar.org" 200

# Helper: generate_report
generate_report "REFLECTION_TEST_REPORT.md"
```

---

## Phase 1: GitHub Organization Validation

**Commands:**
```bash
# List repos
gh repo list mvp-glaciar-org --limit 10

# Check PAT scopes
gh auth status

# Create test repo (if doesn't exist)
gh repo create mvp-glaciar-org/test-reflection-ai --public

# Delete stale test repos (cleanup)
gh repo delete mvp-glaciar-org/test-reflection-ai --confirm
```

**Pass Conditions:**
- `gh repo list` returns at least 1 repo
- `gh auth status` shows scopes: `repo`, `org:read`, `admin:org_hook` (or similar)
- Able to create and delete repos in the org

---

## Phase 2: AWS Infrastructure Validation

**Commands:**
```bash
# Query Terraform outputs
cd terraform
terraform output -json | jq '.ecs_dev_cluster_arn.value'

# List ECS clusters
aws ecs list-clusters --profile chile --region us-east-1

# Describe ECS cluster
aws ecs describe-clusters --clusters backstage-apps-dev \
  --profile chile --region us-east-1

# Verify ALB
aws elbv2 describe-load-balancers --profile chile --region us-east-1 \
  --query 'LoadBalancers[?contains(LoadBalancerName, `backstage-apps-dev`)]'

# Verify listeners
aws elbv2 describe-listeners --load-balancer-arn <ALB_ARN> \
  --profile chile --region us-east-1
```

**Pass Conditions:**
- Terraform outputs exist and are non-empty
- Both ECS clusters exist (arn:aws:ecs:...:cluster/backstage-apps-dev/prod)
- ALB exists for each environment
- HTTPS listener (port 443) exists on each ALB

---

## Phase 3: Route53 DNS Validation

**Commands:**
```bash
# Query Route53 records
aws route53 list-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --profile chile --region us-east-1 \
  --query 'ResourceRecordSets[?Name==`*.dev.glaciar.org.`]'

# Test DNS resolution
nslookup test-nslookup.dev.glaciar.org

# Get ALB IP
ALB_IP=$(dig +short <alb-dns-name> | tail -1)

# Verify CNAME/Alias matches
dig +short test-nslookup.dev.glaciar.org | grep -q $ALB_IP
```

**Pass Conditions:**
- Both wildcard records exist (`*.dev.glaciar.org` and `*.prod.glaciar.org`)
- DNS resolves test subdomains to ALB
- nslookup works without errors

---

## Phase 4: Scaffolder Template Validation

**Commands:**
```bash
# Check template file exists
test -f backstage-portal/examples/template/ai-ops-assistant/template.yaml

# Validate YAML syntax
yq eval '.' backstage-portal/examples/template/ai-ops-assistant/template.yaml > /dev/null

# Extract form fields
yq eval '.spec.parameters[0].properties | keys' template.yaml

# Check for deploy_to_ecs parameter
yq eval '.spec.parameters[] | select(.properties.deploy_to_ecs)' template.yaml | grep -q "deploy_to_ecs"

# Verify GitHub Actions reference
yq eval '.spec.steps[] | select(.action=="github:actions:dispatch")' template.yaml | \
  grep -q "deploy-service.yml"
```

**Pass Conditions:**
- Template file exists and is valid YAML
- Form includes `deploy_to_ecs` boolean parameter
- Form includes `ecs_environment` enum (dev | prod)
- `github:actions:dispatch` step references correct workflow

---

## Phase 5: Service Deployment Test

**Workflow:**

1. **Create test service repo** in `mvp-glaciar-org`
   ```bash
   gh repo create mvp-glaciar-org/test-reflection-ai --public \
     --description "Reflection test service"
   ```

2. **Commit initial code** (minimal frontend + backend)
   ```bash
   git clone mvp-glaciar-org/test-reflection-ai
   # Copy content from ai-ops-assistant template
   git push
   ```

3. **Trigger deploy-service.yml workflow** via `gh workflow run`
   ```bash
   gh workflow run deploy-service.yml \
     -f service_name=test-reflection-ai \
     -f environment=dev \
     -f bedrock_model_id="anthropic.claude-3-haiku-20240307-v1:0" \
     --repo Pabloin/DevOpsDays-BA
   ```

4. **Monitor workflow** (poll until completion)
   ```bash
   gh run watch <run-id> --repo Pabloin/DevOpsDays-BA
   ```

5. **Verify ECS service**
   ```bash
   aws ecs describe-services \
     --cluster backstage-apps-dev \
     --services test-reflection-ai-dev \
     --profile chile --region us-east-1 \
     --query 'services[0].{status: status, runningCount: runningCount}'
   ```

6. **Test DNS resolution**
   ```bash
   nslookup test-reflection-ai.dev.backstage.glaciar.org
   ```

7. **Test HTTPS endpoint**
   ```bash
   curl -k -I https://test-reflection-ai.dev.backstage.glaciar.org
   # Expected: 200 OK
   ```

8. **Test API health check**
   ```bash
   curl -k https://test-reflection-ai.dev.backstage.glaciar.org/api/health
   # Expected: {"status":"ok"}
   ```

9. **Test Bedrock chat endpoint**
   ```bash
   curl -k -X POST https://test-reflection-ai.dev.backstage.glaciar.org/api/chat \
     -H "Content-Type: application/json" \
     -d '{"message":"Hello"}'
   # Expected: {"response":"...","model":"..."}
   ```

**Pass Conditions:**
- Workflow completes successfully (no errors in GitHub Actions logs)
- ECS service reaches "running" status with runningCount >= 1
- DNS resolves to ALB IP
- HTTPS returns 200 (frontend served)
- `/api/health` returns 200 with JSON
- `/api/chat` returns 200 with Bedrock response

---

## Phase 6: Cleanup & Report

**Cleanup commands:**
```bash
# Delete ECS service
aws ecs update-service \
  --cluster backstage-apps-dev \
  --service test-reflection-ai-dev \
  --desired-count 0

# Wait for service to stabilize
aws ecs wait services-stable \
  --cluster backstage-apps-dev \
  --services test-reflection-ai-dev

# Delete service (Terraform will handle it, but for safety)
# Or remove module from terraform/services.tf and re-apply

# Delete test repo
gh repo delete mvp-glaciar-org/test-reflection-ai --confirm

# Verify no test resources remain
aws ecs describe-services --cluster backstage-apps-dev \
  --services test-reflection-ai-dev
# Expected: ServiceNotFoundException or empty services list
```

**Report template** (`REFLECTION_TEST_REPORT.md`):
```markdown
# Environment Reflection Test Report
Date: 2026-04-07 14:23:45

## Summary
- **Overall Status**: ✅ PASS / ❌ FAIL
- **Duration**: 12m 34s
- **Passed**: 18/18
- **Failed**: 0/18

## Phase Results
### Phase 1: GitHub Organization ✅
- [x] mvp-glaciar-org accessible
- [x] PAT has correct scopes
- [x] Can create/delete repos

### Phase 2: AWS Infrastructure ✅
- [x] Terraform outputs valid
- [x] ECS clusters exist
- [x] ALBs configured
- [x] Listeners configured

... (all phases)

## Errors
None

## Next Steps
Environment is ready for DevOpsDays demo!
```

---

## Timeline

Each phase runs sequentially, no parallelization (cleaner error handling):

| Phase | Est. Time |
|-------|-----------|
| 1. GitHub | 2m |
| 2. AWS Infra | 3m |
| 3. Route53 DNS | 2m |
| 4. Template | 1m |
| 5. Deployment | 8m (workflow + ECS stabilization) |
| 6. Cleanup + Report | 3m |
| **Total** | **~19m** |

---

## Error Handling

If any phase fails:

1. **Stop execution** — don't proceed to cleanup
2. **Print detailed error** — include command, exit code, stderr
3. **Save partial report** — show which checks passed/failed
4. **Provide debugging hints** — e.g., "Check terraform.tfvars exists" or "Verify AWS credentials"
5. **Leave resources for inspection** — don't auto-cleanup on failure

Example failure output:
```
❌ Phase 5: Service Deployment Test — FAILED
  Test: ECS service reached running state
  Expected: runningCount >= 1
  Actual: runningCount = 0, status = "PROVISIONING" (after 5m timeout)
  
  Debugging hints:
  - Check CloudWatch logs: /ecs/backstage-apps-dev/test-reflection-ai-dev
  - Verify task definition exists: aws ecs describe-task-definition --task-definition test-reflection-ai-dev
  - Check ALB target group health: aws elbv2 describe-target-health --target-group-arn <TG_ARN>
  
  Next steps:
  1. Run: tail -50 /tmp/reflection-test.log
  2. Check CloudWatch for task failures
  3. Verify image exists in ECR
```

---

## Files to Create

```
.kiro/specs/14-environment-reflection/
  ├─ requirements.md             # Requirements
  ├─ design.md                   # Design
  ├─ tasks.md                    # Checklist
  ├─ .config.kiro                # Spec metadata
  └─ test/
      ├─ reflection-test.sh      # Main test runner
      └─ REFLECTION_TEST_GUIDE.md # Usage guide
```
