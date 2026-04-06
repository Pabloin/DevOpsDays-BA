# Implementation Plan: AI Ops Assistant Template (`08-ai-ops-assistant-template`)

## Overview

Build the Backstage scaffolder template and all generated app content files. Work proceeds in order: backend first (core Bedrock integration), then frontend (chat UI), then docker-compose + README, then the template YAML that wires everything together.

## Tasks

- [x] 1. Create backend (Node.js/Express + Bedrock)
  - [x] 1.1 Create `backend/package.json` with `express`, `@aws-sdk/client-bedrock-runtime`, `cors`, `dotenv`
  - [x] 1.2 Create `backend/index.js`:
    - [x] Read `../prompt.md` at startup
    - [x] `POST /api/chat` — calls `InvokeModel`, returns full response
    - [x] `POST /api/chat/stream` — calls `InvokeModelWithResponseStream`, streams SSE
    - [x] CORS enabled for frontend origin
    - [x] Model ID and region from env vars
  - [x] 1.3 Create `backend/.env.example` with `BEDROCK_MODEL_ID`, `AWS_REGION`, `PORT`
  - _Requirements: 3.1–3.8_

- [x] 2. Create frontend (React/Vite chat UI)
  - [x] 2.1 Create `frontend/package.json` with `react`, `react-dom`, `vite`
  - [x] 2.2 Create `frontend/vite.config.js` with `/api` proxy to backend
  - [x] 2.3 Create `frontend/src/App.jsx`:
    - [x] Chat message history (user + assistant bubbles)
    - [x] Input field + send button
    - [x] Streaming response display (token by token)
    - [x] Service name in header (from `${{ values.service_name }}`)
  - [x] 2.4 Create `frontend/src/main.jsx` and `frontend/index.html`
  - [x] 2.5 Create `frontend/src/index.css` with minimal dark chat UI styles
  - _Requirements: 4.1–4.6_

- [x] 3. Create shared files
  - [x] 3.1 Create `prompt.md` with default system prompt (templated from form input)
  - [x] 3.2 Create `docker-compose.yml` with `frontend` and `backend` services
  - [x] 3.3 Create `catalog-info.yaml` with Component kind, techdocs annotation, owner from form
  - [x] 3.4 Create `README.md` with local dev, prompt customization, and deploy instructions
  - _Requirements: 2.3–2.6, 5.1–5.4, 6.1–6.4, 7.1–7.3_

- [x] 4. Create template YAML (`template.yaml`)
  - [x] 4.1 Define 3-step scaffold form (service details, AI config, repo location)
  - [x] 4.2 Add `fetch:template` step pointing to `content/` directory
  - [x] 4.3 Add `publish:github` step
  - [x] 4.4 Add `catalog:register` step
  - [x] 4.5 Register the template in `app-config.production.yaml` catalog locations
  - _Requirements: 1.1–1.6, 6.1–6.4_

- [ ] 5. Test end-to-end
  - [ ] 5.1 Run template locally (`yarn start`), scaffold a test service
  - [ ] 5.2 Verify generated repo structure matches design
  - [ ] 5.3 Run `docker compose up` in generated repo, test chat UI with real Bedrock call
  - [ ] 5.4 Verify component appears in Backstage catalog

- [x] 6. Commit, push, and deploy
  - [x] 6.1 Create branch `feature/08-ai-ops-assistant-template`
  - [x] 6.2 Commit all template files
  - [x] 6.3 Push and merge to main (triggers CI/CD deploy)
  - [x] 6.4 Verify template appears in Backstage Create page

- [x] 7. Fix scaffolder push 404 (PR #5, PR #6)
  - [x] 7.1 Diagnosed: `publish:github` uses user's OAuth token for git push, not integration PAT
  - [x] 7.2 Root cause: GitHub OAuth provider missing `additionalScopes: [repo]`
  - [x] 7.3 Added `additionalScopes: [repo]` to GitHub auth in app-config.yaml and app-config.production.yaml
  - [x] 7.4 Added `repoVisibility: public`, `protectDefaultBranch: false`, `gitAuthorName/Email` to templates
  - [x] 7.5 Added push retry patch (`patch-scaffolder-push-retry.js`) for GitHub race condition
  - [x] 7.6 Added `scaffolder.defaultAuthor` in app-config.yaml
  - [x] 7.7 Deploy and verify scaffolder push succeeds (confirmed 2026-04-06, retry 2/3 works)
  - _See: `ERROR_REPO_PUSH.md` for full diagnosis_
