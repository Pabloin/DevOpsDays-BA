# Requirements Document

## Introduction

Re-introduce a NAT Gateway in a single Availability Zone so that ECS Fargate tasks in private subnets
can reach external APIs (GitHub OAuth, npm registries, etc.) while keeping the cost at ~$16/month
instead of the original ~$35/month dual-AZ setup.

This change is needed because spec `05-nat-to-endpoints` removed all outbound internet access from
private subnets. While VPC endpoints cover AWS service traffic (ECR, Secrets Manager, CloudWatch Logs),
the Backstage backend requires outbound HTTPS to `github.com` for the OAuth token exchange flow.
Without it, GitHub authentication fails silently with a 401 error.

## Glossary

- **NAT_Gateway**: An AWS managed service that provides outbound internet access for resources in private subnets.
- **EIP**: An Elastic IP address allocated and associated with the NAT Gateway.
- **Private_Route_Table**: The route table associated with private subnets where ECS tasks run.
- **VPC_Endpoints**: Existing VPC Interface/Gateway Endpoints for AWS services (unchanged by this spec).

## Requirements

### Requirement 1: Single-AZ NAT Gateway

**User Story:** As a platform engineer, I want a NAT Gateway in one AZ, so that ECS tasks can reach external APIs at half the cost of a multi-AZ setup.

#### Acceptance Criteria

1. THE VPC_Module SHALL provision one `aws_eip` resource for the NAT Gateway.
2. THE VPC_Module SHALL provision one `aws_nat_gateway` resource in the first public subnet.
3. THE NAT_Gateway SHALL be tagged with standard project/environment tags.

### Requirement 2: Private Route Table Default Route

**User Story:** As a platform engineer, I want a default route in the private route table pointing to the NAT Gateway, so that outbound internet traffic from private subnets is routed through it.

#### Acceptance Criteria

1. THE Private_Route_Table SHALL contain a `0.0.0.0/0` route pointing to the NAT Gateway.
2. THE existing VPC Endpoint routes (S3 Gateway) SHALL remain unchanged and take precedence for AWS service traffic.

### Requirement 3: Preserve VPC Endpoints

**User Story:** As a platform engineer, I want existing VPC endpoints to remain in place, so that AWS service traffic stays on private paths and avoids NAT Gateway data processing charges.

#### Acceptance Criteria

1. ALL existing VPC Interface Endpoints (ecr.api, ecr.dkr, secretsmanager, logs) SHALL remain unchanged.
2. THE S3 Gateway Endpoint SHALL remain unchanged.
3. THE Endpoint Security Group SHALL remain unchanged.

### Requirement 4: ECS Outbound Connectivity

**User Story:** As a platform engineer, I want ECS tasks to reach github.com over HTTPS, so that the Backstage GitHub OAuth token exchange works correctly.

#### Acceptance Criteria

1. WHEN an ECS_Task makes an HTTPS request to `github.com`, THE request SHALL be routed through the NAT Gateway and succeed.
2. WHEN an ECS_Task makes an HTTPS request to an AWS service endpoint, THE request SHALL continue to use the VPC Endpoint (not the NAT Gateway).

### Requirement 5: Cost Efficiency

**User Story:** As a platform engineer, I want the NAT Gateway in a single AZ only, so that the fixed cost is ~$16/month instead of ~$32/month.

#### Acceptance Criteria

1. THE VPC_Module SHALL provision exactly one NAT Gateway (not one per AZ).
2. THE cost documentation SHALL be updated to reflect the new monthly estimate.
