# Deployment

## Docker Deployment

### Build Images

```bash
# Backend
docker build -t ${{ values.service_name }}-backend ./backend

# Frontend
docker build -t ${{ values.service_name }}-frontend ./frontend
```

### Run with Docker Compose

```bash
docker-compose up -d
```

This starts:
- Backend on port 3001
- Frontend on port 3000

## AWS Deployment

### Prerequisites

- AWS account with Bedrock access
- ECR repositories for images
- ECS cluster or EC2 instances
- Secrets Manager for credentials

### Push to ECR

```bash
# Login to ECR
aws ecr get-login-password --region ${{ values.aws_region }} | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.${{ values.aws_region }}.amazonaws.com

# Tag and push backend
docker tag ${{ values.service_name }}-backend:latest \
  <account-id>.dkr.ecr.${{ values.aws_region }}.amazonaws.com/${{ values.service_name }}-backend:latest
docker push <account-id>.dkr.ecr.${{ values.aws_region }}.amazonaws.com/${{ values.service_name }}-backend:latest

# Tag and push frontend
docker tag ${{ values.service_name }}-frontend:latest \
  <account-id>.dkr.ecr.${{ values.aws_region }}.amazonaws.com/${{ values.service_name }}-frontend:latest
docker push <account-id>.dkr.ecr.${{ values.aws_region }}.amazonaws.com/${{ values.service_name }}-frontend:latest
```

### ECS Task Definition

Example task definition for ECS Fargate:

```json
{
  "family": "${{ values.service_name }}",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [
    {
      "name": "backend",
      "image": "<account-id>.dkr.ecr.${{ values.aws_region }}.amazonaws.com/${{ values.service_name }}-backend:latest",
      "portMappings": [
        {
          "containerPort": 3001,
          "protocol": "tcp"
        }
      ],
      "secrets": [
        {
          "name": "AWS_ACCESS_KEY_ID",
          "valueFrom": "arn:aws:secretsmanager:${{ values.aws_region }}:<account-id>:secret:${{ values.service_name }}-aws-creds:AWS_ACCESS_KEY_ID::"
        },
        {
          "name": "AWS_SECRET_ACCESS_KEY",
          "valueFrom": "arn:aws:secretsmanager:${{ values.aws_region }}:<account-id>:secret:${{ values.service_name }}-aws-creds:AWS_SECRET_ACCESS_KEY::"
        }
      ],
      "environment": [
        {
          "name": "AWS_REGION",
          "value": "${{ values.aws_region }}"
        },
        {
          "name": "BEDROCK_MODEL",
          "value": "${{ values.bedrock_model }}"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/${{ values.service_name }}-backend",
          "awslogs-region": "${{ values.aws_region }}",
          "awslogs-stream-prefix": "ecs"
        }
      }
    },
    {
      "name": "frontend",
      "image": "<account-id>.dkr.ecr.${{ values.aws_region }}.amazonaws.com/${{ values.service_name }}-frontend:latest",
      "portMappings": [
        {
          "containerPort": 80,
          "protocol": "tcp"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/${{ values.service_name }}-frontend",
          "awslogs-region": "${{ values.aws_region }}",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

### Create ECS Service

```bash
aws ecs create-service \
  --cluster your-cluster \
  --service-name ${{ values.service_name }} \
  --task-definition ${{ values.service_name }} \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx],assignPublicIp=ENABLED}" \
  --load-balancers "targetGroupArn=arn:aws:elasticloadbalancing:...,containerName=frontend,containerPort=80"
```

## Environment-Specific Configuration

### Development
- Use local AWS credentials
- CORS allows localhost
- Debug logging enabled

### Staging
- Use IAM roles for ECS tasks
- CORS allows staging domain
- Info logging

### Production
- Use IAM roles for ECS tasks
- CORS restricted to production domain
- Error logging only
- Enable CloudWatch alarms

## Monitoring

### CloudWatch Logs

View logs in CloudWatch:
- Backend: `/ecs/${{ values.service_name }}-backend`
- Frontend: `/ecs/${{ values.service_name }}-frontend`

### Metrics

Key metrics to monitor:
- Bedrock invocation count
- Bedrock latency
- Error rate
- Container CPU/memory usage

## Troubleshooting

### Backend can't connect to Bedrock

Check:
1. AWS credentials are valid
2. IAM role has `bedrock:InvokeModel` permission
3. Bedrock is available in your region
4. Model ID is correct

### Frontend can't reach backend

Check:
1. CORS_ORIGIN is configured correctly
2. Backend is running and accessible
3. Network security groups allow traffic
4. Load balancer health checks pass

### High latency

Consider:
- Using a faster model (Claude Haiku)
- Implementing response streaming
- Adding caching for common queries
- Scaling backend horizontally
