# Requirements Document

## Introduction

Replace the NAT Gateway in the Backstage portal's AWS VPC infrastructure with VPC Interface Endpoints
to reduce monthly infrastructure costs while maintaining private network connectivity for ECS Fargate
tasks to required AWS services (ECR, Secrets Manager, CloudWatch Logs).

The NAT Gateway costs approximately $35/month in fixed charges regardless of usage. VPC Interface
Endpoints for the same set of services cost approximately $7/month, reducing total infrastructure
spend from ~$88/month to ~$60/month.

## Glossary

- **VPC_Module**: The Terraform module at `terraform/modules/vpc/` that provisions the VPC, subnets, route tables, and network resources.
- **NAT_Gateway**: An AWS managed service that provides outbound internet access for resources in private subnets.
- **VPC_Endpoint**: An AWS PrivateLink resource that allows private connectivity between a VPC and AWS services without traversing the public internet.
- **Interface_Endpoint**: A VPC Endpoint type that provisions an ENI with a private IP in the subnet, used for most AWS services.
- **Gateway_Endpoint**: A VPC Endpoint type that adds a route to a route table, used for S3 and DynamoDB (free of charge).
- **Private_Subnet**: A VPC subnet with no direct route to the internet gateway, used to host ECS Fargate tasks.
- **ECS_Task**: An ECS Fargate container running the Backstage backend application in a private subnet.
- **Endpoint_Security_Group**: An AWS security group controlling inbound HTTPS access to VPC Interface Endpoints from private subnets.

## Requirements

### Requirement 1: Remove NAT Gateway

**User Story:** As a platform engineer, I want to remove the NAT Gateway from the VPC module, so that the infrastructure no longer incurs the ~$35/month fixed NAT Gateway cost.

#### Acceptance Criteria

1. THE VPC_Module SHALL NOT provision an `aws_nat_gateway` resource.
2. THE VPC_Module SHALL NOT provision an `aws_eip` resource for a NAT Gateway.
3. THE Private_Subnet route table SHALL NOT contain a default route (`0.0.0.0/0`) pointing to a NAT Gateway.

### Requirement 2: Provision VPC Interface Endpoints for AWS Services

**User Story:** As a platform engineer, I want VPC Interface Endpoints for ECR, Secrets Manager, and CloudWatch Logs, so that ECS Fargate tasks in private subnets can reach those AWS services without a NAT Gateway.

#### Acceptance Criteria

1. THE VPC_Module SHALL provision an Interface_Endpoint for `com.amazonaws.{region}.ecr.api`.
2. THE VPC_Module SHALL provision an Interface_Endpoint for `com.amazonaws.{region}.ecr.dkr`.
3. THE VPC_Module SHALL provision an Interface_Endpoint for `com.amazonaws.{region}.secretsmanager`.
4. THE VPC_Module SHALL provision an Interface_Endpoint for `com.amazonaws.{region}.logs`.
5. WHEN an Interface_Endpoint is provisioned, THE VPC_Module SHALL enable private DNS on the endpoint so that existing AWS SDK calls resolve to the private endpoint without code changes.
6. WHEN an Interface_Endpoint is provisioned, THE VPC_Module SHALL attach the endpoint to all private subnets.

### Requirement 3: Provision S3 Gateway Endpoint

**User Story:** As a platform engineer, I want an S3 Gateway Endpoint, so that ECR image layer pulls (which use S3) succeed from private subnets at no additional cost.

#### Acceptance Criteria

1. THE VPC_Module SHALL provision a Gateway_Endpoint for `com.amazonaws.{region}.s3`.
2. THE VPC_Module SHALL associate the S3 Gateway_Endpoint with the private route table so that S3 traffic from private subnets is routed through the endpoint.

### Requirement 4: Endpoint Security Group

**User Story:** As a platform engineer, I want a dedicated security group for VPC endpoints, so that only resources in private subnets can initiate HTTPS connections to the endpoints.

#### Acceptance Criteria

1. THE VPC_Module SHALL provision an Endpoint_Security_Group scoped to the VPC.
2. THE Endpoint_Security_Group SHALL allow inbound TCP traffic on port 443 from the private subnet CIDR blocks.
3. THE VPC_Module SHALL attach the Endpoint_Security_Group to all Interface_Endpoints.

### Requirement 5: Region Variable

**User Story:** As a platform engineer, I want the VPC module to accept an `aws_region` input variable, so that endpoint service names can be constructed dynamically for any AWS region.

#### Acceptance Criteria

1. THE VPC_Module SHALL declare an `aws_region` input variable of type `string`.
2. WHEN constructing VPC endpoint service names, THE VPC_Module SHALL use `var.aws_region` to form the service name (e.g., `com.amazonaws.${var.aws_region}.ecr.api`).
3. THE root Terraform module SHALL pass `var.aws_region` to the VPC_Module.

### Requirement 6: ECS Task Connectivity

**User Story:** As a platform engineer, I want ECS Fargate tasks to continue pulling images from ECR and reading secrets from Secrets Manager after the NAT Gateway is removed, so that the application deployment is unaffected.

#### Acceptance Criteria

1. WHEN an ECS_Task starts, THE ECS_Task SHALL successfully pull its container image from ECR via the Interface_Endpoints.
2. WHEN an ECS_Task starts, THE ECS_Task SHALL successfully retrieve secrets from Secrets Manager via the Interface_Endpoint.
3. WHEN an ECS_Task emits logs, THE ECS_Task SHALL successfully deliver logs to CloudWatch Logs via the Interface_Endpoint.
4. IF the Endpoint_Security_Group does not permit port 443 from the ECS task's subnet, THEN THE ECS_Task SHALL fail to start with a connectivity error rather than silently timing out.

### Requirement 7: Cost Documentation

**User Story:** As a platform engineer, I want the infrastructure cost breakdown documented, so that the team understands the cost impact of this change.

#### Acceptance Criteria

1. THE repository SHALL contain a cost breakdown document listing monthly estimates for each infrastructure resource.
2. THE cost breakdown document SHALL state the previous monthly cost with NAT Gateway (~$88/month) and the new monthly cost with VPC Endpoints (~$60/month).
3. THE cost breakdown document SHALL list all five VPC endpoints (ecr.api, ecr.dkr, secretsmanager, logs, s3) with their types and cost contributions.
