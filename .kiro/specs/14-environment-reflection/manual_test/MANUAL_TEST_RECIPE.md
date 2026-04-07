# Manual Test Recipe - Environment Reflection

This guide walks you through testing specs 12-13 infrastructure **step by step with Claude's guidance**.

Each phase has commands you run, and Claude will help interpret results and guide next steps.

---

## Before You Start

Ensure you have:
```bash
cd /Users/pabloinchausti/Desktop/repos/devopsdaysba/terraform
```

And your environment is ready:
```bash
source .env.glaciar.org
export AWS_PROFILE=chile
```

---

## Phase 1: GitHub Organization Validation

### Step 1.1: List repos in mvp-glaciar-org
```bash
gh repo list mvp-glaciar-org --limit 10
```

**What to expect**: List of repos owned by `mvp-glaciar-org`

**Questions for Claude**:
- Do repos show up? ✅
- Any error messages? ❌

---

### Step 1.2: Verify GitHub authentication
```bash
gh auth status
```

**What to expect**: Shows `github.com` and login user

**Questions for Claude**:
- Authenticated? ✅
- Correct user showing? ✅

---

### Step 1.3: Check for stale test repos
```bash
gh repo list mvp-glaciar-org --limit 100 | grep -E "test-|demo-|reflection-"
```

**What to expect**: May show old test repos (safe to delete) or empty

**Questions for Claude**:
- Any stale repos found? (If yes, should we delete them?)

---

## Phase 2: AWS Infrastructure Validation

### Step 2.1: Source AWS environment
```bash
source terraform/.env.glaciar.org
echo "AWS_PROFILE is set to: $AWS_PROFILE"
```

**What to expect**: `AWS_PROFILE is set to: chile`

**Questions for Claude**:
- Correct profile set? ✅

---

### Step 2.2: Query Terraform outputs
```bash
cd terraform
terraform output -json 2>/dev/null | jq 'keys' | head -20
```

**What to expect**: List of output keys like `ecs_dev_cluster_name`, `ecs_prod_cluster_name`, etc.

**Questions for Claude**:
- Outputs available? ✅
- See `ecs_dev_cluster_name` and `ecs_prod_cluster_name`? ✅

---

### Step 2.3: Get ECS cluster names
```bash
terraform output -json 2>/dev/null | jq -r '.ecs_dev_cluster_name.value, .ecs_prod_cluster_name.value'
```

**What to expect**:
```
backstage-apps-dev
backstage-apps-prod
```

**Questions for Claude**:
- Both clusters listed? ✅
- Names match expected pattern? ✅

---

### Step 2.4: Verify ECS clusters exist in AWS
```bash
aws ecs list-clusters --profile chile --region us-east-1 | jq -r '.clusterArns[]'
```

**What to expect**: ARNs for both clusters should show up

**Questions for Claude**:
- See both `backstage-apps-dev` and `backstage-apps-prod`? ✅

---

### Step 2.5: Get ALB info
```bash
aws elbv2 describe-load-balancers --profile chile --region us-east-1 | jq '.LoadBalancers[] | select(.LoadBalancerName | contains("apps-")) | {name: .LoadBalancerName, dns: .DNSName}'
```

**What to expect**: Two ALBs (apps-dev-alb, apps-prod-alb) with DNS names

**Questions for Claude**:
- See 2 ALBs (dev + prod)? ✅
- Both have DNS names? ✅

---

## Phase 3: Route53 DNS Validation

### Step 3.1: Find Route53 hosted zone
```bash
aws route53 list-hosted-zones --profile chile | jq '.HostedZones[] | {name: .Name, id: .Id}'
```

**What to expect**: Should see `glaciar.org.` hosted zone

**Questions for Claude**:
- Found `glaciar.org` zone? ✅
- What's the zone ID? (copy it for next step)

---

### Step 3.2: List Route53 records
```bash
ZONE_ID="YOUR_ZONE_ID_HERE"  # Replace with actual ID from step 3.1
aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID --profile chile | jq '.ResourceRecordSets[] | select(.Name | contains("*.")) | {name: .Name, type: .Type}'
```

**What to expect**: Wildcard records for `*.dev.backstage.glaciar.org` and `*.prod.backstage.glaciar.org`

**Questions for Claude**:
- See both wildcard records? ✅
- Both are alias records pointing to ALBs? ✅

---

### Step 3.3: Test DNS resolution
```bash
nslookup test-check.dev.glaciar.org
```

**What to expect**: Should resolve to an IP (the ALB IP)

**Questions for Claude**:
- DNS resolves? ✅
- Points to ALB? ✅

---

## Phase 4: Scaffolder Template Validation

### Step 4.1: Check template file exists
```bash
ls -la backstage-portal/examples/template/ai-ops-assistant/template.yaml
```

**What to expect**: File should exist and show size > 0

**Questions for Claude**:
- Template file found? ✅
- Has content (size > 0)? ✅

---

### Step 4.2: Validate YAML
```bash
yq eval '.' backstage-portal/examples/template/ai-ops-assistant/template.yaml > /dev/null && echo "✅ YAML valid" || echo "❌ YAML invalid"
```

**What to expect**: `✅ YAML valid`

**Questions for Claude**:
- YAML is valid? ✅
- If not, any error messages?

---

### Step 4.3: Check for deploy_to_ecs parameter
```bash
grep -A3 "deploy_to_ecs" backstage-portal/examples/template/ai-ops-assistant/template.yaml | head -5
```

**What to expect**: YAML section with `deploy_to_ecs` form field

**Questions for Claude**:
- Field found? ✅
- Is it a boolean? ✅

---

### Step 4.4: Check for workflow reference
```bash
grep "deploy-service.yml" backstage-portal/examples/template/ai-ops-assistant/template.yaml
```

**What to expect**: Line referencing the workflow

**Questions for Claude**:
- Workflow reference found? ✅

---

## Phase 5: Service Deployment Test (Optional - Real Deployment)

**⚠️ This phase actually deploys a test service. Only do if you want full end-to-end test.**

### Step 5.1: Create test repo
```bash
gh repo create mvp-glaciar-org/test-reflection-ai --public --description "Reflection test service"
```

**What to expect**: Confirmation repo created or "already exists"

**Questions for Claude**:
- Repo created or already exists? ✅

---

### Step 5.2: Clone and commit test code
```bash
git clone https://github.com/mvp-glaciar-org/test-reflection-ai.git /tmp/test-reflection-ai
cd /tmp/test-reflection-ai
echo "# Test Service" > README.md
git config user.email "test@glaciar.org"
git config user.name "Test User"
git add README.md
git commit -m "init: test service"
git push
```

**What to expect**: Code pushed successfully

**Questions for Claude**:
- Code pushed? ✅

---

### Step 5.3: Trigger deployment workflow
```bash
gh workflow run deploy-service.yml \
  -f service_name=test-reflection-ai \
  -f environment=dev \
  -f bedrock_model_id="anthropic.claude-3-haiku-20240307-v1:0" \
  --repo Pabloin/DevOpsDays-BA
```

**What to expect**: Workflow dispatched

**Questions for Claude**:
- Workflow triggered? ✅
- Got run ID?

---

### Step 5.4: Wait for deployment
```bash
# Check workflow status
gh run list --repo Pabloin/DevOpsDays-BA --limit 1

# Or watch real-time
gh run watch <RUN_ID> --repo Pabloin/DevOpsDays-BA --exit-status
```

**What to expect**: Workflow should complete in ~5-10 minutes

**Questions for Claude**:
- Workflow completed? ✅
- Any errors in logs? ❌

---

### Step 5.5: Verify ECS service running
```bash
aws ecs describe-services \
  --cluster backstage-apps-dev \
  --services test-reflection-ai-dev \
  --profile chile \
  --region us-east-1 | jq '.services[0] | {status: .status, running: .runningCount, desired: .desiredCount}'
```

**What to expect**:
```json
{
  "status": "ACTIVE",
  "running": 1,
  "desired": 1
}
```

**Questions for Claude**:
- Service running? ✅
- Running count >= 1? ✅

---

### Step 5.6: Test service endpoint
```bash
curl -k https://test-reflection-ai.dev.backstage.glaciar.org/api/health
```

**What to expect**: JSON response with status `ok` or similar

**Questions for Claude**:
- Service responds? ✅
- Health check passes? ✅

---

### Step 5.7: Test Bedrock integration
```bash
curl -k -X POST https://test-reflection-ai.dev.backstage.glaciar.org/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"Hello test"}'
```

**What to expect**: JSON response with Bedrock completion

**Questions for Claude**:
- Endpoint responds? ✅
- Got Bedrock response? ✅

---

## Phase 6: Cleanup (After Testing)

### Step 6.1: Scale down service
```bash
aws ecs update-service \
  --cluster backstage-apps-dev \
  --service test-reflection-ai-dev \
  --desired-count 0 \
  --profile chile \
  --region us-east-1
```

**What to expect**: Service updated

**Questions for Claude**:
- Service scaled down? ✅

---

### Step 6.2: Delete test repo
```bash
gh repo delete mvp-glaciar-org/test-reflection-ai --confirm
```

**What to expect**: Repo deleted

**Questions for Claude**:
- Repo deleted? ✅

---

## Summary

At each step:
1. **Run the command** provided
2. **Share the output** with Claude
3. **Claude will interpret** and guide next steps
4. **Move to next step** when Claude confirms ✅

This is an **interactive walkthrough** — you control the pace and Claude provides guidance.

---

## Quick Reference: Commands by Phase

**Phase 1 (GitHub)**
```bash
gh repo list mvp-glaciar-org --limit 10
gh auth status
```

**Phase 2 (AWS Infrastructure)**
```bash
source terraform/.env.glaciar.org
terraform output -json | jq 'keys'
aws ecs list-clusters --profile chile --region us-east-1
aws elbv2 describe-load-balancers --profile chile --region us-east-1
```

**Phase 3 (DNS)**
```bash
aws route53 list-hosted-zones --profile chile
nslookup test-check.dev.glaciar.org
```

**Phase 4 (Template)**
```bash
ls backstage-portal/examples/template/ai-ops-assistant/template.yaml
yq eval '.' backstage-portal/examples/template/ai-ops-assistant/template.yaml
grep deploy-service.yml backstage-portal/examples/template/ai-ops-assistant/template.yaml
```

---

**Ready to start? Run Phase 1, Step 1.1!**
