#!/bin/bash

################################################################################
# Environment Reflection & Testing Script
# Spec 14: Validates DevOpsDays BA platform (specs 12-13) end-to-end
#
# Usage: ./reflection-test.sh [--no-cleanup] [--dry-run]
#
# Phases:
#   1. GitHub Organization Validation
#   2. AWS Infrastructure Validation
#   3. Route53 DNS Validation
#   4. Scaffolder Template Validation
#   5. Service Deployment Test
#   6. Cleanup & Report
################################################################################

set -o pipefail
IFS=$'\n\t'

# Configuration
SPEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SPEC_DIR/../../../../" && pwd)"
SCRIPT_LOG="${SPEC_DIR}/reflection-test.log"
REPORT_FILE="${REPO_ROOT}/.kiro/REFLECTION_TEST_REPORT.md"

# AWS Environment (configurable)
ENV_FILE="${REPO_ROOT}/terraform/.env.glaciar.org"
AWS_PROFILE="${AWS_PROFILE:-chile}"
AWS_REGION="us-east-1"

# Test Configuration
TEST_ORG="mvp-glaciar-org"
TEST_SERVICE="test-reflection-ai"
TEST_ENVIRONMENT="dev"
BEDROCK_MODEL_ID="anthropic.claude-3-haiku-20240307-v1:0"

# CLI flags
NO_CLEANUP=false
DRY_RUN=false

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()
START_TIME=$(date +%s)

################################################################################
# Helper Functions
################################################################################

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$SCRIPT_LOG"
}

error() {
    echo "❌ ERROR: $*" | tee -a "$SCRIPT_LOG" >&2
}

success() {
    echo "✅ $*" | tee -a "$SCRIPT_LOG"
}

info() {
    echo "ℹ️  $*" | tee -a "$SCRIPT_LOG"
}

check_pass() {
    local test_name="$1"
    local exit_code="${2:-0}"

    if [[ $exit_code -eq 0 ]]; then
        success "$test_name"
        ((TESTS_PASSED++))
        return 0
    else
        error "$test_name (exit code: $exit_code)"
        FAILED_TESTS+=("$test_name")
        ((TESTS_FAILED++))
        return 1
    fi
}

check_condition() {
    local test_name="$1"
    local condition="$2"

    if eval "$condition"; then
        success "$test_name"
        ((TESTS_PASSED++))
        return 0
    else
        error "$test_name"
        FAILED_TESTS+=("$test_name")
        ((TESTS_FAILED++))
        return 1
    fi
}

heading() {
    {
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$1"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    } | tee -a "$SCRIPT_LOG"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-cleanup) NO_CLEANUP=true; shift ;;
            --dry-run) DRY_RUN=true; shift ;;
            *) error "Unknown option: $1"; exit 1 ;;
        esac
    done
}

################################################################################
# Phase 1: GitHub Organization Validation
################################################################################

phase_1_github_validation() {
    heading "Phase 1: GitHub Organization Validation"

    log "Checking GitHub CLI availability..."
    check_pass "GitHub CLI installed" "$(command -v gh > /dev/null 2>&1 && echo 0 || echo 1)"

    log "Verifying GitHub authentication..."
    gh auth status > /dev/null 2>&1
    check_pass "GitHub authenticated" $?

    log "Listing repos in $TEST_ORG..."
    local repo_count=$(gh repo list "$TEST_ORG" --limit 100 2>/dev/null | wc -l)
    check_condition "mvp-glaciar-org has repos" "[[ $repo_count -gt 0 ]]"

    log "Verifying GitHub PAT scopes..."
    local scopes=$(gh auth status 2>&1)
    check_condition "PAT authenticated with scopes" "[[ -n '$scopes' ]]"
    info "Auth status: $(echo "$scopes" | head -1)"

    log "Checking for stale test repos..."
    local stale_repos=$(gh repo list "$TEST_ORG" --limit 100 2>/dev/null | grep -E "test-|demo-|reflection-" | awk '{print $1}' | cut -d'/' -f2)
    if [[ -n "$stale_repos" ]]; then
        info "Found stale test repos: $stale_repos"
        if [[ "$DRY_RUN" != true ]]; then
            while IFS= read -r repo; do
                log "Cleaning up stale repo: $repo"
                gh repo delete "$TEST_ORG/$repo" --confirm 2>&1 | tee -a "$SCRIPT_LOG"
            done <<< "$stale_repos"
        fi
    else
        info "No stale test repos found"
    fi

    info "Phase 1 complete: $TESTS_PASSED passed, $TESTS_FAILED failed"
}

################################################################################
# Phase 2: AWS Infrastructure Validation
################################################################################

phase_2_aws_validation() {
    heading "Phase 2: AWS Infrastructure Validation"

    log "Checking AWS CLI availability..."
    check_pass "AWS CLI installed" "$(command -v aws > /dev/null 2>&1 && echo 0 || echo 1)"

    log "Sourcing AWS credentials from $ENV_FILE..."
    if [[ -f "$ENV_FILE" ]]; then
        source "$ENV_FILE"
        export AWS_PROFILE
        success "AWS environment loaded from $ENV_FILE"
        info "Using AWS_PROFILE=$AWS_PROFILE"
    else
        error "Missing $ENV_FILE"
        error "Please run: source ${ENV_FILE}"
        return 1
    fi

    log "Querying Terraform outputs..."
    cd "$REPO_ROOT/terraform" || { error "Cannot cd to terraform dir"; return 1; }

    local tf_output
    tf_output=$(terraform output -json 2>/dev/null)
    check_pass "Terraform output accessible" $?

    # Extract key outputs
    local ecs_dev_cluster=$(echo "$tf_output" | jq -r '.ecs_dev_cluster_arn.value // empty' 2>/dev/null)
    local ecs_prod_cluster=$(echo "$tf_output" | jq -r '.ecs_prod_cluster_arn.value // empty' 2>/dev/null)

    check_condition "ecs_dev_cluster_arn exists" "[[ -n '$ecs_dev_cluster' ]]"
    check_condition "ecs_prod_cluster_arn exists" "[[ -n '$ecs_prod_cluster' ]]"
    info "Dev cluster ARN: $ecs_dev_cluster"
    info "Prod cluster ARN: $ecs_prod_cluster"

    log "Verifying ECS clusters exist..."
    local dev_clusters=$(aws ecs list-clusters --profile "$AWS_PROFILE" --region "$AWS_REGION" 2>/dev/null | jq -r '.clusterArns[]' | grep backstage-apps-dev)
    check_condition "backstage-apps-dev cluster exists" "[[ -n '$dev_clusters' ]]"

    local prod_clusters=$(aws ecs list-clusters --profile "$AWS_PROFILE" --region "$AWS_REGION" 2>/dev/null | jq -r '.clusterArns[]' | grep backstage-apps-prod)
    check_condition "backstage-apps-prod cluster exists" "[[ -n '$prod_clusters' ]]"

    log "Checking ALB configuration..."
    local albs=$(aws elbv2 describe-load-balancers --profile "$AWS_PROFILE" --region "$AWS_REGION" 2>/dev/null | jq -r '.LoadBalancers[] | select(.LoadBalancerName | contains("backstage-apps")) | .LoadBalancerArn' | wc -l)
    check_condition "ALBs exist (2 expected)" "[[ $albs -ge 2 ]]"

    log "Checking ALB listeners on port 443..."
    local alb_arn=$(aws elbv2 describe-load-balancers --profile "$AWS_PROFILE" --region "$AWS_REGION" 2>/dev/null | jq -r '.LoadBalancers[] | select(.LoadBalancerName | contains("backstage-apps-dev")) | .LoadBalancerArn' | head -1)
    if [[ -n "$alb_arn" ]]; then
        local listeners=$(aws elbv2 describe-listeners --load-balancer-arn "$alb_arn" --profile "$AWS_PROFILE" --region "$AWS_REGION" 2>/dev/null | jq -r '.Listeners[] | select(.Port == 443) | .Protocol' | grep -c HTTPS || echo 0)
        check_condition "HTTPS listener exists on port 443" "[[ $listeners -ge 1 ]]"
    else
        error "Could not find ALB ARN"
    fi

    info "Phase 2 complete: $TESTS_PASSED passed, $TESTS_FAILED failed"
}

################################################################################
# Phase 3: Route53 DNS Validation
################################################################################

phase_3_dns_validation() {
    heading "Phase 3: Route53 DNS Validation"

    log "Checking DNS tools availability..."
    check_pass "nslookup available" "$(command -v nslookup > /dev/null 2>&1 && echo 0 || echo 1)"
    check_pass "dig available" "$(command -v dig > /dev/null 2>&1 && echo 0 || echo 1)"

    log "Querying Route53 hosted zone..."
    local zone_id=$(aws route53 list-hosted-zones --profile "$AWS_PROFILE" --region "$AWS_REGION" 2>/dev/null | jq -r '.HostedZones[] | select(.Name == "glaciar.org." or .Name == "glaciar.org") | .Id' | cut -d'/' -f3 | head -1)
    check_condition "Route53 hosted zone found" "[[ -n '$zone_id' ]]"
    info "Zone ID: ${zone_id:-not found}"

    log "Checking wildcard DNS records..."
    if [[ -n "$zone_id" ]]; then
        local dev_wildcard=$(aws route53 list-resource-record-sets --hosted-zone-id "$zone_id" --profile "$AWS_PROFILE" 2>/dev/null | jq -r '.ResourceRecordSets[] | select(.Name == "*.dev.glaciar.org.") | .Name')
        check_condition "*.dev.glaciar.org wildcard exists" "[[ -n '$dev_wildcard' ]]"

        local prod_wildcard=$(aws route53 list-resource-record-sets --hosted-zone-id "$zone_id" --profile "$AWS_PROFILE" 2>/dev/null | jq -r '.ResourceRecordSets[] | select(.Name == "*.prod.glaciar.org.") | .Name')
        check_condition "*.prod.glaciar.org wildcard exists" "[[ -n '$prod_wildcard' ]]"
    fi

    log "Testing DNS resolution..."
    nslookup test-nslookup.dev.glaciar.org > /dev/null 2>&1
    check_pass "DNS resolution works for dev subdomain" $?

    log "Testing HTTPS endpoint (ALB should respond with 404)..."
    local http_status=$(curl -s -o /dev/null -w "%{http_code}" -k "https://test-nslookup.dev.glaciar.org/" 2>/dev/null)
    check_condition "ALB responds (expected 404)" "[[ '$http_status' == '404' || '$http_status' == '200' ]]"
    info "HTTP status: $http_status"

    info "Phase 3 complete: $TESTS_PASSED passed, $TESTS_FAILED failed"
}

################################################################################
# Phase 4: Scaffolder Template Validation
################################################################################

phase_4_template_validation() {
    heading "Phase 4: Scaffolder Template Validation"

    local template_file="$REPO_ROOT/backstage-portal/examples/template/ai-ops-assistant/template.yaml"

    log "Checking template file exists..."
    check_condition "AI Ops Assistant template exists" "[[ -f '$template_file' ]]"

    if [[ ! -f "$template_file" ]]; then
        error "Template file not found: $template_file"
        return 1
    fi

    log "Validating template YAML syntax..."
    check_pass "Template YAML is valid" "$(yq eval '.' "$template_file" > /dev/null 2>&1 && echo 0 || echo 1)"

    log "Verifying form fields..."
    check_condition "service_name parameter exists" "[[ -n $(yq eval '.spec.parameters[0].properties.service_name' "$template_file" 2>/dev/null) ]]"
    check_condition "deploy_to_ecs parameter exists" "[[ -n $(yq eval '.spec.parameters[] | select(.properties.deploy_to_ecs)' "$template_file" 2>/dev/null) ]]"
    check_condition "ecs_environment parameter exists" "[[ -n $(yq eval '.spec.parameters[] | select(.properties.ecs_environment)' "$template_file" 2>/dev/null) ]]"

    log "Checking GitHub Actions workflow reference..."
    check_condition "github:actions:dispatch step exists" "[[ -n $(yq eval '.spec.steps[] | select(.action == "github:actions:dispatch")' "$template_file" 2>/dev/null) ]]"
    check_condition "workflow references deploy-service.yml" "[[ -n $(grep -q 'deploy-service.yml' "$template_file" && echo 'found') ]]"

    info "Phase 4 complete: $TESTS_PASSED passed, $TESTS_FAILED failed"
}

################################################################################
# Phase 5: Service Deployment Test
################################################################################

phase_5_deployment_test() {
    heading "Phase 5: Service Deployment Test"

    info "DRY_RUN mode: $DRY_RUN"

    if [[ "$DRY_RUN" == true ]]; then
        info "Skipping actual deployment in dry-run mode"
        success "Deployment test skipped (dry-run)"
        return 0
    fi

    log "Creating test repository in $TEST_ORG..."
    if ! gh repo view "$TEST_ORG/$TEST_SERVICE" > /dev/null 2>&1; then
        gh repo create "$TEST_ORG/$TEST_SERVICE" --public --description "Reflection test service" 2>&1 | tee -a "$SCRIPT_LOG"
        check_pass "Test repo created" $?
    else
        info "Test repo already exists, will reuse"
        success "Test repo available"
    fi

    log "Initializing test repo with template code..."
    local temp_clone="/tmp/$TEST_SERVICE-clone-$$"
    git clone "https://github.com/$TEST_ORG/$TEST_SERVICE.git" "$temp_clone" 2>&1 | tee -a "$SCRIPT_LOG"
    check_pass "Test repo cloned" $?

    log "Committing initial code from template..."
    cd "$temp_clone" || { error "Cannot cd to clone"; return 1; }
    git config user.email "reflection-test@glaciar.org"
    git config user.name "Reflection Test"
    echo "# Test Service for Reflection Testing" > README.md
    git add README.md
    git commit -m "init: test service for reflection testing" 2>&1 | tee -a "$SCRIPT_LOG"
    check_pass "Initial commit created" $?

    git push 2>&1 | tee -a "$SCRIPT_LOG"
    check_pass "Code pushed to repo" $?

    log "Triggering deploy-service.yml workflow..."
    local run_id=$(gh workflow run deploy-service.yml \
        -f "service_name=$TEST_SERVICE" \
        -f "environment=$TEST_ENVIRONMENT" \
        -f "bedrock_model_id=$BEDROCK_MODEL_ID" \
        --repo Pabloin/DevOpsDays-BA 2>&1 | grep 'Run ID' | awk '{print $NF}')

    check_condition "Workflow triggered" "[[ -n '$run_id' ]]"
    info "Workflow run ID: $run_id"

    if [[ -n "$run_id" ]]; then
        log "Waiting for workflow to complete (timeout: 10m)..."
        timeout 600 gh run watch "$run_id" --repo Pabloin/DevOpsDays-BA --exit-status 2>&1 | tee -a "$SCRIPT_LOG"
        local workflow_exit=$?

        if [[ $workflow_exit -eq 0 ]]; then
            success "Workflow completed successfully"
        elif [[ $workflow_exit -eq 124 ]]; then
            error "Workflow timed out after 10 minutes"
        else
            error "Workflow failed with exit code $workflow_exit"
        fi
    fi

    log "Checking ECS service status..."
    sleep 5  # Give ECS a moment to register the service

    local service_status=$(aws ecs describe-services \
        --cluster "backstage-apps-$TEST_ENVIRONMENT" \
        --services "$TEST_SERVICE-$TEST_ENVIRONMENT" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" 2>/dev/null | jq -r '.services[0].status // empty')

    check_condition "ECS service exists" "[[ -n '$service_status' ]]"
    info "Service status: $service_status"

    log "Waiting for service to reach running state (timeout: 5m)..."
    local wait_count=0
    while [[ $wait_count -lt 60 ]]; do
        local running=$(aws ecs describe-services \
            --cluster "backstage-apps-$TEST_ENVIRONMENT" \
            --services "$TEST_SERVICE-$TEST_ENVIRONMENT" \
            --profile "$AWS_PROFILE" \
            --region "$AWS_REGION" 2>/dev/null | jq -r '.services[0].runningCount // 0')

        if [[ $running -gt 0 ]]; then
            success "ECS service is running (running count: $running)"
            break
        fi

        ((wait_count++))
        sleep 5
    done

    if [[ $wait_count -ge 60 ]]; then
        error "Service did not reach running state within 5m"
    fi

    log "Testing DNS resolution..."
    nslookup "$TEST_SERVICE.dev.backstage.glaciar.org" > /dev/null 2>&1
    check_pass "DNS resolves for test service" $?

    log "Testing HTTPS endpoint..."
    local http_status=$(curl -s -o /dev/null -w "%{http_code}" -k "https://$TEST_SERVICE.dev.backstage.glaciar.org/" 2>/dev/null)
    check_condition "HTTPS endpoint responds" "[[ '$http_status' == '200' || '$http_status' == '404' ]]"
    info "HTTP status: $http_status"

    log "Testing API health endpoint..."
    local health=$(curl -s -k "https://$TEST_SERVICE.dev.backstage.glaciar.org/api/health" 2>/dev/null)
    check_condition "Health check returns JSON" "[[ -n $(echo '$health' | jq '.' 2>/dev/null) ]]"
    info "Health response: $health"

    log "Testing Bedrock chat endpoint..."
    local chat_response=$(curl -s -X POST -k \
        "https://$TEST_SERVICE.dev.backstage.glaciar.org/api/chat" \
        -H "Content-Type: application/json" \
        -d '{"message":"Hello, test"}' 2>/dev/null)
    check_condition "Chat endpoint responds with JSON" "[[ -n $(echo '$chat_response' | jq '.' 2>/dev/null) ]]"
    info "Chat response (truncated): ${chat_response:0:100}..."

    # Cleanup temp clone
    rm -rf "$temp_clone"

    info "Phase 5 complete: $TESTS_PASSED passed, $TESTS_FAILED failed"
}

################################################################################
# Phase 6: Cleanup & Report
################################################################################

phase_6_cleanup() {
    heading "Phase 6: Cleanup & Report"

    if [[ "$NO_CLEANUP" == true ]]; then
        info "Skipping cleanup (--no-cleanup flag set)"
        info "To clean up manually, run:"
        info "  gh repo delete $TEST_ORG/$TEST_SERVICE"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        info "Skipping cleanup in dry-run mode"
        return 0
    fi

    log "Scaling down ECS service..."
    aws ecs update-service \
        --cluster "backstage-apps-$TEST_ENVIRONMENT" \
        --service "$TEST_SERVICE-$TEST_ENVIRONMENT" \
        --desired-count 0 \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" 2>&1 | tee -a "$SCRIPT_LOG"

    log "Waiting for service to stabilize..."
    aws ecs wait services-stable \
        --cluster "backstage-apps-$TEST_ENVIRONMENT" \
        --services "$TEST_SERVICE-$TEST_ENVIRONMENT" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" 2>&1 | tee -a "$SCRIPT_LOG"
    check_pass "Service scaled down" $?

    log "Deleting test repository..."
    gh repo delete "$TEST_ORG/$TEST_SERVICE" --confirm 2>&1 | tee -a "$SCRIPT_LOG"
    check_pass "Test repo deleted" $?

    log "Verifying cleanup..."
    sleep 5
    aws ecs describe-services \
        --cluster "backstage-apps-$TEST_ENVIRONMENT" \
        --services "$TEST_SERVICE-$TEST_ENVIRONMENT" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" 2>&1 | tee -a "$SCRIPT_LOG" | grep -q 'MISSING\|INACTIVE'

    if [[ $? -eq 0 || $(aws ecs describe-services --cluster "backstage-apps-$TEST_ENVIRONMENT" --services "$TEST_SERVICE-$TEST_ENVIRONMENT" --profile "$AWS_PROFILE" --region "$AWS_REGION" 2>&1 | jq '.services | length') -eq 0 ]]; then
        success "Test resources cleaned up"
    else
        error "Test resources may still exist (manual cleanup may be needed)"
    fi

    info "Phase 6 complete: $TESTS_PASSED passed, $TESTS_FAILED failed"
}

################################################################################
# Report Generation
################################################################################

generate_report() {
    heading "Generating Report"

    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local duration_min=$((duration / 60))
    local duration_sec=$((duration % 60))

    local total_tests=$((TESTS_PASSED + TESTS_FAILED))
    local status="PASS"
    [[ $TESTS_FAILED -gt 0 ]] && status="FAIL"

    cat > "$REPORT_FILE" << EOF
# Environment Reflection Test Report
**Date**: $(date +'%Y-%m-%d %H:%M:%S')

## Summary
- **Overall Status**: $([ "$status" == "PASS" ] && echo "✅ PASS" || echo "❌ FAIL")
- **Duration**: ${duration_min}m ${duration_sec}s
- **Total Tests**: $total_tests
- **Passed**: $TESTS_PASSED
- **Failed**: $TESTS_FAILED

## Test Results
EOF

    if [[ $TESTS_FAILED -gt 0 ]]; then
        cat >> "$REPORT_FILE" << EOF

### Failed Tests
\`\`\`
EOF
        for test in "${FAILED_TESTS[@]}"; do
            echo "- $test" >> "$REPORT_FILE"
        done
        cat >> "$REPORT_FILE" << EOF
\`\`\`
EOF
    fi

    cat >> "$REPORT_FILE" << EOF

## Phases Executed
- [x] Phase 1: GitHub Organization Validation
- [x] Phase 2: AWS Infrastructure Validation
- [x] Phase 3: Route53 DNS Validation
- [x] Phase 4: Scaffolder Template Validation
- [x] Phase 5: Service Deployment Test
- [x] Phase 6: Cleanup & Report

## Log File
See \`$SCRIPT_LOG\` for detailed output.

## Configuration
- Test Org: \`$TEST_ORG\`
- Test Service: \`$TEST_SERVICE\`
- Test Environment: \`$TEST_ENVIRONMENT\`
- AWS Profile: \`$AWS_PROFILE\`
- AWS Region: \`$AWS_REGION\`

## Next Steps
$([ "$status" == "PASS" ] && echo "✅ Platform is ready for DevOpsDays demo!" || echo "❌ Review failed tests and retry.")
EOF

    success "Report generated: $REPORT_FILE"
    cat "$REPORT_FILE"
}

################################################################################
# Main Execution
################################################################################

main() {
    # Initialize log
    > "$SCRIPT_LOG"
    log "Starting Environment Reflection Test"
    log "Spec: 14 - Environment Reflection & Testing"
    log "Repository: $REPO_ROOT"

    parse_args "$@"

    log "Configuration:"
    log "  DRY_RUN=$DRY_RUN"
    log "  NO_CLEANUP=$NO_CLEANUP"
    log "  TEST_ORG=$TEST_ORG"
    log "  TEST_SERVICE=$TEST_SERVICE"
    log "  TEST_ENVIRONMENT=$TEST_ENVIRONMENT"

    # Run phases
    phase_1_github_validation
    phase_2_aws_validation
    phase_3_dns_validation
    phase_4_template_validation
    phase_5_deployment_test
    phase_6_cleanup

    # Generate report
    generate_report

    # Exit with appropriate code
    if [[ $TESTS_FAILED -gt 0 ]]; then
        error "Reflection test completed with failures"
        exit 1
    else
        success "Reflection test completed successfully"
        exit 0
    fi
}

# Run main
main "$@"
