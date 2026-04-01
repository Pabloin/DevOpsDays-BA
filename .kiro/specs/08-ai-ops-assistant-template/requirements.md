# Requirements Document

## Introduction

Add a Backstage scaffolder template that generates a production-ready full-stack AI Ops Assistant application. The generated app has a React chat UI (frontend) and a Node.js/Express backend that proxies requests to AWS Bedrock. The system prompt is customizable at scaffold time and editable post-scaffold via a committed `prompt.md` file.

The template is the centrepiece demo for the DevOpsDays BA talk: a developer fills in a form in Backstage, clicks Create, and 30 seconds later has a working AI assistant repo registered in the catalog.

## Glossary

- **Template**: The Backstage scaffolder template YAML registered in the catalog
- **Scaffold_Form**: The multi-step form shown to the user in Backstage Create
- **Generated_App**: The repository produced by running the template
- **System_Prompt**: The initial instruction given to the AI model, stored in `prompt.md`
- **Bedrock_Model**: The AWS Bedrock foundation model used (Claude or Nova)
- **Backend**: The Node.js/Express server in the Generated_App that calls Bedrock
- **Frontend**: The React/Vite chat UI in the Generated_App

---

## Requirements

### Requirement 1: Scaffold Form

**User Story:** As a developer, I want a guided form in Backstage so I can configure my AI assistant without editing code manually.

#### Acceptance Criteria

1. THE Scaffold_Form SHALL have a **Service name** field (string, required) used as the repo name and component title.
2. THE Scaffold_Form SHALL have a **Description** field (string, required) describing what the assistant helps with.
3. THE Scaffold_Form SHALL have a **System prompt** field (multiline string, required) pre-filled with a default ops assistant prompt.
4. THE Scaffold_Form SHALL have a **Bedrock model** selector with options:
   - `anthropic.claude-3-haiku-20240307-v1:0` (default — fast, cheap)
   - `anthropic.claude-3-5-sonnet-20240620-v1:0`
   - `amazon.nova-lite-v1:0`
   - `amazon.nova-pro-v1:0`
5. THE Scaffold_Form SHALL have a **GitHub owner** field (RepoUrlPicker) for the target org/user.
6. THE Scaffold_Form SHALL have an **AWS region** field (string, default `us-east-1`) for the Bedrock endpoint.

---

### Requirement 2: Generated App Structure

**User Story:** As a developer, I want the scaffolded repo to have a clear full-stack structure so I can understand and extend it immediately.

#### Acceptance Criteria

1. THE Generated_App SHALL contain a `frontend/` directory with a React/Vite application.
2. THE Generated_App SHALL contain a `backend/` directory with a Node.js/Express server.
3. THE Generated_App SHALL contain a `prompt.md` file at the repo root with the System_Prompt from the form.
4. THE Generated_App SHALL contain a `catalog-info.yaml` at the repo root.
5. THE Generated_App SHALL contain a `README.md` explaining how to run and deploy the app.
6. THE Generated_App SHALL contain a `docker-compose.yml` for running both services locally with one command.

---

### Requirement 3: Backend (Node.js/Express + Bedrock)

**User Story:** As a developer, I want the backend to proxy chat requests to AWS Bedrock so browser credentials are never exposed.

#### Acceptance Criteria

1. THE Backend SHALL expose a `POST /api/chat` endpoint accepting `{ messages: [...] }`.
2. THE Backend SHALL read `prompt.md` at startup and use it as the system prompt for every Bedrock request.
3. THE Backend SHALL call the AWS Bedrock `InvokeModel` API using the `@aws-sdk/client-bedrock-runtime` package.
4. THE Backend SHALL read the Bedrock model ID from the `BEDROCK_MODEL_ID` environment variable.
5. THE Backend SHALL read the AWS region from the `AWS_REGION` environment variable.
6. THE Backend SHALL authenticate to Bedrock using the ambient IAM role (no hardcoded credentials).
7. THE Backend SHALL support streaming responses via `POST /api/chat/stream` using server-sent events.
8. THE Backend SHALL return CORS headers allowing requests from the frontend origin.

---

### Requirement 4: Frontend (React/Vite chat UI)

**User Story:** As a developer, I want a clean chat UI so I can immediately test and demo the AI assistant.

#### Acceptance Criteria

1. THE Frontend SHALL display a chat interface with a message history and an input field.
2. THE Frontend SHALL send user messages to `POST /api/chat` on the Backend.
3. THE Frontend SHALL display the AI response as it streams in (streaming UX).
4. THE Frontend SHALL display the assistant name (from the service name) in the UI header.
5. THE Frontend SHALL be built with React and Vite (no Create React App).
6. THE Frontend SHALL proxy `/api` requests to the Backend via Vite's `server.proxy` in development.

---

### Requirement 5: System Prompt Customization

**User Story:** As a developer, I want to update the assistant's personality by editing a file in the repo, so I don't need to touch application code.

#### Acceptance Criteria

1. THE Backend SHALL read `prompt.md` from the filesystem at startup (not hardcoded in source).
2. WHEN `prompt.md` is edited and the app is redeployed, THE assistant behavior SHALL change accordingly.
3. THE `prompt.md` file SHALL be pre-populated with the System_Prompt entered in the Scaffold_Form.
4. THE `README.md` SHALL document how to update the system prompt.

---

### Requirement 6: Catalog Registration

**User Story:** As a platform engineer, I want every scaffolded AI assistant auto-registered in the Backstage catalog.

#### Acceptance Criteria

1. THE template SHALL include a Register step that adds `catalog-info.yaml` to the Backstage catalog after repo creation.
2. THE `catalog-info.yaml` SHALL set `kind: Component`, `spec.type: service`, `spec.lifecycle: experimental`.
3. THE `catalog-info.yaml` SHALL set `spec.owner` to the GitHub owner from the form.
4. THE `catalog-info.yaml` SHALL include the `backstage.io/techdocs-ref: dir:.` annotation so TechDocs works.

---

### Requirement 7: Local Development

**User Story:** As a developer, I want to run the full stack locally with one command for fast iteration.

#### Acceptance Criteria

1. THE `docker-compose.yml` SHALL define two services: `frontend` and `backend`.
2. WHEN `docker compose up` is run with AWS credentials in the environment, BOTH services SHALL start and the chat UI SHALL be accessible at `http://localhost:3000`.
3. THE `README.md` SHALL document the local development workflow including AWS credential setup.
