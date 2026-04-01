# Implementation Plan: AI Ops Assistant Template (`08-ai-ops-assistant-template`)

## Overview

Build the Backstage scaffolder template and all generated app content files. Work proceeds in order: backend first (core Bedrock integration), then frontend (chat UI), then docker-compose + README, then the template YAML that wires everything together.

## Tasks

- [x] 1. Create backend (Node.js/Express + Bedrock)
  - [ ] 1.1 Create `backend/package.json` with `express`, `@aws-sdk/client-bedrock-runtime`, `cors`, `dotenv`
  - [ ] 1.2 Create `backend/index.js`:
    - Read `../prompt.md` at startup
    - `POST /api/chat` — calls `InvokeModel`, returns full response
    - `POST /api/chat/stream` — calls `InvokeModelWithResponseStream`, streams SSE
    - CORS enabled for frontend origin
    - Model ID and region from env vars
  - [ ] 1.3 Create `backend/.env.example` with `BEDROCK_MODEL_ID`, `AWS_REGION`, `PORT`
  - _Requirements: 3.1–3.8_

- [x] 2. Create frontend (React/Vite chat UI)
  - [ ] 2.1 Create `frontend/package.json` with `react`, `react-dom`, `vite`
  - [ ] 2.2 Create `frontend/vite.config.js` with `/api` proxy to backend
  - [ ] 2.3 Create `frontend/src/App.jsx`:
    - Chat message history (user + assistant bubbles)
    - Input field + send button
    - Streaming response display (token by token)
    - Service name in header (from `${{ values.service_name }}`)
  - [ ] 2.4 Create `frontend/src/main.jsx` and `frontend/index.html`
  - [ ] 2.5 Create `frontend/src/index.css` with minimal dark chat UI styles
  - _Requirements: 4.1–4.6_

- [x] 3. Create shared files
  - [ ] 3.1 Create `prompt.md` with default system prompt (templated from form input)
  - [ ] 3.2 Create `docker-compose.yml` with `frontend` and `backend` services
  - [ ] 3.3 Create `catalog-info.yaml` with Component kind, techdocs annotation, owner from form
  - [ ] 3.4 Create `README.md` with local dev, prompt customization, and deploy instructions
  - _Requirements: 2.3–2.6, 5.1–5.4, 6.1–6.4, 7.1–7.3_

- [x] 4. Create template YAML (`template.yaml`)
  - [ ] 4.1 Define 3-step scaffold form (service details, AI config, repo location)
  - [ ] 4.2 Add `fetch:template` step pointing to `content/` directory
  - [ ] 4.3 Add `publish:github` step
  - [ ] 4.4 Add `catalog:register` step
  - [ ] 4.5 Register the template in `app-config.production.yaml` catalog locations
  - _Requirements: 1.1–1.6, 6.1–6.4_

- [ ] 5. Test end-to-end
  - [ ] 5.1 Run template locally (`yarn start`), scaffold a test service
  - [ ] 5.2 Verify generated repo structure matches design
  - [ ] 5.3 Run `docker compose up` in generated repo, test chat UI with real Bedrock call
  - [ ] 5.4 Verify component appears in Backstage catalog

- [ ] 6. Commit, push, and deploy
  - [ ] 6.1 Create branch `feature/08-ai-ops-assistant-template`
  - [ ] 6.2 Commit all template files
  - [ ] 6.3 Push and merge to main (triggers CI/CD deploy)
  - [ ] 6.4 Verify template appears in Backstage Create page
