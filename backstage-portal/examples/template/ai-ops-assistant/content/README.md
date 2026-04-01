# ${{ values.service_name }}

${{ values.description }}

Powered by AWS Bedrock — model: `${{ values.bedrock_model }}`

## Local Development

### Prerequisites
- Node.js 22+
- AWS credentials with Bedrock access (`bedrock:InvokeModel`, `bedrock:InvokeModelWithResponseStream`)

### Run locally

```bash
# Backend
cd backend
cp .env.example .env   # edit if needed
npm install
npm run dev

# Frontend (new terminal)
cd frontend
npm install
npm run dev
```

Open http://localhost:3000

### Run with Docker Compose

```bash
# Export AWS credentials first
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...   # if using temporary credentials

docker compose up --build
```

Open http://localhost:3000

## Customizing the system prompt

Edit `prompt.md` at the repo root and redeploy. No code changes needed.

```markdown
You are an AI assistant for the payments team...
```

The backend reads this file at startup — change it, restart the backend, and the assistant's personality changes immediately.

## Switching models

Change `BEDROCK_MODEL_ID` in your environment or `.env`:

| Model | ID |
|---|---|
| Claude 3 Haiku (fast) | `anthropic.claude-3-haiku-20240307-v1:0` |
| Claude 3.5 Sonnet | `anthropic.claude-3-5-sonnet-20240620-v1:0` |
| Nova Lite | `amazon.nova-lite-v1:0` |
| Nova Pro | `amazon.nova-pro-v1:0` |

## IAM permissions required

```json
{
  "Effect": "Allow",
  "Action": [
    "bedrock:InvokeModel",
    "bedrock:InvokeModelWithResponseStream"
  ],
  "Resource": "arn:aws:bedrock:*::foundation-model/*"
}
```
