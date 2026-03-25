# Project: Backstage Portal

## Overview
This is a Backstage developer portal using the new frontend system (declarative plugin architecture).

## Structure
- `backstage-portal/` — monorepo root managed with Yarn 4 workspaces
  - `packages/app/` — frontend (React, Backstage new frontend system)
  - `packages/backend/` — backend (Node.js, `@backstage/backend-defaults`)
  - `plugins/` — custom plugins (currently empty)
  - `examples/` — sample catalog entities, templates, org data

## Tech Stack
- Node.js 22+
- TypeScript ~5.8
- Yarn 4.4.1 (PnP-style workspaces)
- Backstage CLI `^0.36.0`
- Frontend: `createApp` from `@backstage/frontend-defaults` (new declarative system)
- Backend: `createBackend` from `@backstage/backend-defaults`

## Key Config
- App runs on `http://localhost:3000`
- Backend runs on `http://localhost:7007`
- Auth: guest provider (no real auth configured yet)
- Database: `better-sqlite3` in-memory (dev only)
- GitHub integration via `GITHUB_TOKEN` env var
- Permissions: enabled with allow-all policy
- TechDocs: local builder, Docker generator, local publisher

## Backend Plugins Installed
- app, proxy, scaffolder (+ github + notifications modules)
- techdocs, auth (guest provider)
- catalog (+ scaffolder entity model + logs modules)
- permission (allow-all policy)
- search (+ pg engine + catalog/techdocs collators)
- kubernetes
- notifications + signals

## Frontend
- Uses new Backstage frontend system (`alpha` APIs)
- `catalogPlugin` from `@backstage/plugin-catalog/alpha`
- Custom nav module in `packages/app/src/modules/nav/`
- Sidebar includes: catalog, scaffolder, search modal, notifications, settings

## Common Commands
Run from `backstage-portal/`:
```bash
yarn start          # start both app and backend
yarn build:backend  # build backend
yarn tsc            # type check
yarn lint:all       # lint everything
yarn test           # run tests
```

## Notes
- Catalog index page is set as the root path (`/`)
- Organization name is "My Company" — update in `app-config.yaml`
- Production DB config is in `app-config.production.yaml`
