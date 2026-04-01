# Design Document: AI Ops Assistant Template (`08-ai-ops-assistant-template`)

## Overview

A Backstage scaffolder template that generates a full-stack AI Ops Assistant. The demo story for DevOpsDays BA: a developer opens Backstage, fills in a 3-step form, clicks Create, and 30 seconds later has a working AI assistant repo — complete with chat UI, Bedrock-powered backend, and a `prompt.md` they can edit to change the assistant's personality.

---

## Architecture of the Generated App

```
┌─────────────────────────────────────┐
│  Browser                            │
│  React/Vite chat UI (:3000)         │
│  - message history                  │
│  - streaming response               │
└──────────────┬──────────────────────┘
               │ POST /api/chat
               ▼
┌─────────────────────────────────────┐
│  Node.js/Express backend (:3001)    │
│  - reads prompt.md at startup       │
│  - calls Bedrock InvokeModelStream  │
│  - streams SSE back to frontend     │
└──────────────┬──────────────────────┘
               │ AWS SDK (IAM role)
               ▼
┌─────────────────────────────────────┐
│  AWS Bedrock                        │
│  Claude 3 Haiku (default)           │
│  Claude 3.5 Sonnet / Nova (opt.)    │
└─────────────────────────────────────┘
```

## Generated Repo Structure

```
{{service_name}}/
├── frontend/
│   ├── src/
│   │   ├── App.jsx          ← chat UI component
│   │   ├── main.jsx
│   │   └── index.css
│   ├── index.html
│   ├── vite.config.js       ← proxies /api → backend
│   └── package.json
├── backend/
│   ├── index.js             ← Express server + Bedrock
│   ├── package.json
│   └── .env.example
├── prompt.md                ← system prompt (editable)
├── docker-compose.yml       ← local dev: both services
├── catalog-info.yaml        ← Backstage registration
└── README.md
```

---

## Scaffold Form (3 steps)

### Step 1 — Service details
| Field | Type | Default | Notes |
|---|---|---|---|
| Service name | string | — | Used as repo name + component title |
| Description | string | — | What this assistant helps with |

### Step 2 — AI configuration
| Field | Type | Default | Notes |
|---|---|---|---|
| System prompt | textarea | See below | Pre-filled default |
| Bedrock model | select | claude-3-haiku | 4 options |
| AWS region | string | `us-east-1` | Bedrock endpoint region |

**Default system prompt:**
```
You are an AI ops assistant. You help engineers understand services,
diagnose incidents, and follow runbooks. Be concise and practical.
```

### Step 3 — Repository location
| Field | Type | Notes |
|---|---|---|
| GitHub owner | RepoUrlPicker | org or user |
| Repository name | auto-filled from service name | |

---

## Key Design Decisions

### prompt.md as config
The system prompt lives in `prompt.md` at the repo root — not hardcoded in `index.js`. The backend reads it at startup with `fs.readFileSync`. This means teams update their assistant's personality via a PR, not a code change. Natural fit for GitOps.

### Streaming via SSE
The backend uses `InvokeModelWithResponseStream` from Bedrock and pipes the response as Server-Sent Events. The frontend uses `EventSource` (or `fetch` with `ReadableStream`) to show tokens as they arrive. This makes the demo feel alive.

### IAM role — no credentials in repo
The backend uses the default AWS credential chain (`new BedrockRuntimeClient({})`). Locally, developers set `AWS_PROFILE` or `AWS_ACCESS_KEY_ID`. In production (ECS), the task role grants Bedrock access. No credentials in the repo.

### Model switching via env var
`BEDROCK_MODEL_ID` env var controls the model. The form pre-fills it, it goes into `.env.example` and `docker-compose.yml`. Teams switch models by changing one env var.

### Vite proxy for local dev
`vite.config.js` proxies `/api` to `http://localhost:3001`. No CORS issues in development. In production, the frontend is served by the Express backend as static files (single container option) or separately.

---

## Template Files Location

```
backstage-portal/examples/template/
  ai-ops-assistant/           ← new template
    template.yaml             ← scaffolder definition
    content/                  ← files to be templated
      frontend/...
      backend/...
      prompt.md
      docker-compose.yml
      catalog-info.yaml
      README.md
```

---

## Bedrock Models

| Model ID | Name | Speed | Cost | Good for |
|---|---|---|---|---|
| `anthropic.claude-3-haiku-20240307-v1:0` | Claude 3 Haiku | Fast | Low | Default, demos |
| `anthropic.claude-3-5-sonnet-20240620-v1:0` | Claude 3.5 Sonnet | Medium | Medium | Quality answers |
| `amazon.nova-lite-v1:0` | Nova Lite | Fast | Very low | Cost-sensitive |
| `amazon.nova-pro-v1:0` | Nova Pro | Medium | Medium | AWS-native option |

---

## Tasks

See `tasks.md` for implementation steps.
