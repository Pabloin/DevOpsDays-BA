# Backstage Portal

Welcome to the Backstage developer portal documentation.

## Overview

This portal is built with [Backstage](https://backstage.io) and provides:

- Software catalog — browse and manage all services and components
- TechDocs — in-app documentation for every catalog entity
- Software templates — scaffold new services via the Scaffolder
- GitHub authentication — sign in with your GitHub account

## Local Development

Run from `backstage-portal/`:

```bash
yarn start
```

The app runs on `http://localhost:3000` and the backend on `http://localhost:7007`.

## Authentication

GitHub OAuth is configured. You need `AUTH_GITHUB_CLIENT_ID` and `AUTH_GITHUB_CLIENT_SECRET` set in `app-config.local.yaml`.

## Infrastructure

Production deployment uses AWS ECS Fargate with Terraform. See the `terraform/` directory for infrastructure code.
