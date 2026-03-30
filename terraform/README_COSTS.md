# Infrastructure Cost Estimate

Region: `us-east-1` — estimates based on MVP configuration (1 ECS task, minimal traffic).

## Monthly Breakdown

| Resource | Spec | ~$/month |
|---|---|---|
| ALB | 1 LCU baseline | ~$20 |
| RDS | db.t3.micro, Postgres 16, 20GB gp2 | ~$15 |
| ECS Fargate | 0.5 vCPU / 1GB, 1 task 24/7 | ~$15 |
| VPC Endpoints | 4 interface endpoints × $0.01/hr | ~$7 |
| Secrets Manager | 2 secrets | ~$1 |
| ECR | storage + transfers | ~$1 |
| CloudWatch Logs | 30 day retention | ~$1 |
| S3 Gateway Endpoint | free | $0 |
| **Total** | | **~$60/month** |

## Biggest Cost Driver: NAT Gateway

The NAT Gateway (~$35/month) is required because ECS tasks run in private subnets
and need outbound internet access to pull Docker images from ECR and read Secrets Manager.

### Option A — VPC Endpoints (saves ~$35/month)

Replace the NAT Gateway with VPC Interface Endpoints for ECR and Secrets Manager.
ECS tasks stay in private subnets but communicate with AWS services privately.

Endpoints needed:
- `com.amazonaws.us-east-1.ecr.api`
- `com.amazonaws.us-east-1.ecr.dkr`
- `com.amazonaws.us-east-1.secretsmanager`
- `com.amazonaws.us-east-1.logs` (CloudWatch)
- `com.amazonaws.us-east-1.s3` (Gateway endpoint, free — needed by ECR)

Cost: ~$7/month (4 interface endpoints × $0.01/hr) vs $35 for NAT Gateway.

### Option B — Public Subnets for ECS (free, less secure)

Move ECS tasks to public subnets and assign public IPs.
No NAT Gateway or VPC endpoints needed.
Not recommended for production — tasks are directly internet-facing.

## Cost Optimization Summary

| Scenario | ~$/month |
|---|---|
| Current (NAT Gateway) | ~$88 |
| With VPC Endpoints | ~$60 |
| Public subnets for ECS | ~$53 |

## Notes

- RDS `skip_final_snapshot = true` — no snapshot cost on destroy
- ECS desired count is 1 — scale up increases Fargate cost linearly
- ALB cost grows with traffic (LCUs)
- All estimates exclude data transfer out to internet (first 100GB/month is ~$0.09/GB)
