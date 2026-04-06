# Getting Started

## Prerequisites

- Node.js 18+ and npm
- Docker and Docker Compose (for containerized deployment)
- AWS credentials with Bedrock access (for backend)

## Clone the Repository

```bash
git clone https://github.com/${{ values.repo_owner }}/${{ values.service_name }}.git
cd ${{ values.service_name }}
```

## Local Development

### Option 1: Docker Compose (Recommended)

1. Copy the environment file:
   ```bash
   cp backend/.env.example backend/.env
   ```

2. Edit `backend/.env` and add your AWS credentials:
   ```bash
   AWS_REGION=${{ values.aws_region }}
   AWS_ACCESS_KEY_ID=your_access_key
   AWS_SECRET_ACCESS_KEY=your_secret_key
   BEDROCK_MODEL=${{ values.bedrock_model }}
   ```

3. Start the services:
   ```bash
   docker-compose up
   ```

4. Open http://localhost:3000

### Option 2: Manual Setup

#### Backend

```bash
cd backend
npm install
cp .env.example .env
# Edit .env with your AWS credentials
npm start
```

Backend runs on http://localhost:3001

#### Frontend

```bash
cd frontend
npm install
npm run dev
```

Frontend runs on http://localhost:3000

## Testing the Assistant

Once running, you can:

1. Open the chat interface at http://localhost:3000
2. Type a message and press Enter
3. The assistant will respond based on the system prompt in `prompt.md`

## Customizing the System Prompt

Edit `prompt.md` to change the assistant's behavior:

```bash
vim prompt.md
# Restart the backend to apply changes
```

## Next Steps

- [Configuration](configuration.md) - Learn about environment variables
- [Deployment](deployment.md) - Deploy to AWS
