# Implementation Plan: Single-AZ NAT Gateway (`07-single-az-nat`)

## Overview

Add a single-AZ NAT Gateway to restore outbound internet access for ECS tasks, fixing the GitHub
OAuth token exchange failure caused by the removal of the NAT Gateway in spec 05.

## Tasks

- [ ] 1. Add NAT Gateway resources to VPC module
  - Add `aws_eip.nat` with `domain = "vpc"` in `terraform/modules/vpc/main.tf`
  - Add `aws_nat_gateway.main` in the first public subnet (`aws_subnet.public[0].id`)
  - Add `depends_on = [aws_internet_gateway.main]` to the NAT Gateway
  - Tag both resources with standard project/environment tags
  - _Requirements: 1.1, 1.2, 1.3_

- [ ] 2. Add default route to private route table
  - Add `aws_route.private_nat` with `destination_cidr_block = "0.0.0.0/0"` pointing to the NAT Gateway
  - Verify existing VPC endpoint routes are not affected
  - _Requirements: 2.1, 2.2_

- [ ] 3. Verify VPC endpoints are unchanged
  - Run `terraform plan` and confirm zero changes to existing VPC endpoint resources
  - Confirm the S3 Gateway Endpoint route still exists in the private route table
  - _Requirements: 3.1, 3.2, 3.3_

- [ ] 4. Apply and test GitHub OAuth
  - Run `terraform apply` to create the NAT Gateway, EIP, and route
  - Force a new ECS deployment to restart tasks with internet access
  - Open `https://backstage.glaciar.org` and test "Sign in using GitHub"
  - Verify the OAuth popup completes and a valid session is created
  - _Requirements: 4.1, 4.2_

- [ ] 5. Update cost documentation
  - Update `terraform/README_COSTS.md` with the new networking cost (~$23/month)
  - Note the trade-off: single-AZ NAT is cheaper but not HA
  - _Requirements: 5.1, 5.2_

- [ ] 6. Final checkpoint
  - Verify no regressions in ECS task startup, image pulls, secret retrieval, or log delivery
  - Confirm GitHub OAuth sign-in works end-to-end
