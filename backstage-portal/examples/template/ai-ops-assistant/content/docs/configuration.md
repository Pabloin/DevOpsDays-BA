# Configuration

## Environment Variables

### Backend (`backend/.env`)

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `PORT` | Backend server port | `3001` | No |
| `AWS_REGION` | AWS region for Bedrock | `${{ values.aws_region }}` | Yes |
| `AWS_ACCESS_KEY_ID` | AWS access key | - | Yes |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | - | Yes |
| `BEDROCK_MODEL` | Bedrock model ID | `${{ values.bedrock_model }}` | Yes |
| `CORS_ORIGIN` | Allowed CORS origin | `http://localhost:3000` | No |

### Frontend

The frontend is configured via environment variables in the Docker build or Vite config:

| Variable | Description | Default |
|----------|-------------|---------|
| `VITE_API_URL` | Backend API URL | `http://localhost:3001` |

## AWS Bedrock Models

Available models:

- `anthropic.claude-3-haiku-20240307-v1:0` - Fast, cost-effective (recommended)
- `anthropic.claude-3-5-sonnet-20240620-v1:0` - Higher quality, slower
- `amazon.nova-lite-v1:0` - AWS native, very cheap
- `amazon.nova-pro-v1:0` - AWS native, balanced

To change the model, update `BEDROCK_MODEL` in `backend/.env` and restart.

## System Prompt

The system prompt is stored in `prompt.md` and loaded by the backend at startup. To modify:

1. Edit `prompt.md`
2. Restart the backend
3. New conversations will use the updated prompt

Example prompt structure:

```markdown
You are an AI ops assistant for [TEAM/PRODUCT].

Your responsibilities:
- Help engineers understand services
- Diagnose incidents
- Follow runbooks
- Provide concise, actionable advice

Guidelines:
- Be concise and practical
- Use bullet points for lists
- Include relevant commands when helpful
- Ask clarifying questions if needed
```

## CORS Configuration

For production deployments, update `CORS_ORIGIN` in the backend to match your frontend domain:

```bash
CORS_ORIGIN=https://your-frontend-domain.com
```

## AWS IAM Permissions

The AWS credentials must have permissions to invoke Bedrock models:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": "arn:aws:bedrock:*::foundation-model/*"
    }
  ]
}
```
