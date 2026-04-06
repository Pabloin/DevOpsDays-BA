# ${{ values.service_name }}

${{ values.description }}

## Overview

This is an AI-powered operations assistant built with:

- **Frontend**: React + Vite
- **Backend**: Node.js + Express + AWS Bedrock
- **AI Model**: ${{ values.bedrock_model }}
- **AWS Region**: ${{ values.aws_region }}

## Quick Links

- [Getting Started](getting-started.md) - Clone and run locally
- [Configuration](configuration.md) - Environment variables and settings
- [Deployment](deployment.md) - Deploy to AWS

## Architecture

```
┌─────────────┐      ┌─────────────┐      ┌──────────────┐
│   Browser   │─────▶│   Backend   │─────▶│ AWS Bedrock  │
│  (React UI) │◀─────│  (Node.js)  │◀─────│   (Claude)   │
└─────────────┘      └─────────────┘      └──────────────┘
```

The frontend provides a chat interface where users can interact with the AI assistant. The backend proxies requests to AWS Bedrock using the configured model.

## System Prompt

The assistant's behavior is defined by the system prompt in `prompt.md`:

```
${{ values.system_prompt }}
```

You can edit `prompt.md` to change the assistant's personality and capabilities.
