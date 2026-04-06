# Spec 11: TechDocs for Scaffolder Templates

## Overview

Add comprehensive TechDocs documentation to scaffolder templates so that every component created from a template includes ready-to-use documentation accessible via Backstage's TechDocs feature.

## Problem Statement

Components created from scaffolder templates lack documentation. Developers need to manually create docs for each new service, which is time-consuming and often skipped. This leads to:

- Undocumented services in the catalog
- Inconsistent documentation quality
- Developers not knowing how to get started with generated code
- Missing deployment and configuration guides

## Goals

1. Add TechDocs structure to the AI Ops Assistant template
2. Include comprehensive documentation covering:
   - Overview and architecture
   - Getting started (clone, setup, run)
   - Configuration (environment variables, AWS setup)
   - Deployment (Docker, AWS ECS)
3. Make docs accessible via the TechDocs tab in Backstage
4. Use template variables so docs are customized per service

## Non-Goals

- Documenting existing components (only new ones from templates)
- Creating a custom TechDocs theme
- Adding interactive documentation features

## Design

### Documentation Structure

```
content/
├── mkdocs.yml              # TechDocs configuration
├── docs/
│   ├── index.md           # Overview and architecture
│   ├── getting-started.md # Clone, setup, run locally
│   ├── configuration.md   # Environment variables and AWS
│   └── deployment.md      # Docker and ECS deployment
├── catalog-info.yaml      # Already has techdocs-ref annotation
└── ... (other template files)
```

### mkdocs.yml Configuration

```yaml
site_name: ${{ values.service_name }}
site_description: ${{ values.description }}

nav:
  - Home: index.md
  - Getting Started: getting-started.md
  - Configuration: configuration.md
  - Deployment: deployment.md

plugins:
  - techdocs-core
```

### Documentation Content

#### index.md
- Service overview
- Architecture diagram (ASCII art)
- Tech stack
- Quick links to other docs
- System prompt explanation

#### getting-started.md
- Prerequisites
- Clone repository command
- Local development options:
  - Docker Compose (recommended)
  - Manual setup (backend + frontend)
- Testing instructions
- Customizing system prompt

#### configuration.md
- Environment variables table
- AWS Bedrock model options
- System prompt configuration
- CORS setup
- IAM permissions required

#### deployment.md
- Docker build commands
- ECR push instructions
- ECS task definition example
- Service creation command
- Environment-specific configs
- Monitoring and troubleshooting

### Template Variables

All docs use template variables that get replaced when scaffolder runs:

- `${{ values.service_name }}` - Service name
- `${{ values.description }}` - Service description
- `${{ values.aws_region }}` - AWS region
- `${{ values.bedrock_model }}` - AI model ID
- `${{ values.system_prompt }}` - AI system prompt
- `${{ values.repo_owner }}` - GitHub org

## Implementation

### Tasks

- [x] Create mkdocs.yml with navigation structure
- [x] Write index.md with overview and architecture
- [x] Write getting-started.md with setup instructions
- [x] Write configuration.md with env vars and AWS setup
- [x] Write deployment.md with Docker and ECS guides
- [x] Test template variables are replaced correctly
- [x] Commit and push changes

### Files Changed

- `backstage-portal/examples/template/ai-ops-assistant/content/mkdocs.yml` (new)
- `backstage-portal/examples/template/ai-ops-assistant/content/docs/index.md` (new)
- `backstage-portal/examples/template/ai-ops-assistant/content/docs/getting-started.md` (new)
- `backstage-portal/examples/template/ai-ops-assistant/content/docs/configuration.md` (new)
- `backstage-portal/examples/template/ai-ops-assistant/content/docs/deployment.md` (new)

## Testing

### Manual Testing

1. Create a new component using the AI Ops Assistant template
2. Verify the component appears in the catalog
3. Click on the component
4. Click the "TECHDOCS" tab
5. Verify all documentation pages render correctly
6. Verify template variables are replaced with actual values
7. Verify navigation works between pages

### Expected Results

- TechDocs tab shows documentation
- Service name, description, region, model are correct
- Clone command has correct repo URL
- All links and navigation work

## Rollout Plan

1. ✅ Implement TechDocs for AI Ops Assistant template
2. Deploy to production (merge to main)
3. Create a new test component to verify docs work
4. Add TechDocs to other templates (future work)

## Success Metrics

- All new components have documentation
- TechDocs tab is accessible on new components
- Documentation is accurate and helpful
- Developers use the docs to get started

## Future Enhancements

1. Add TechDocs to other templates (simple Node.js service, etc.)
2. Add API documentation section
3. Add troubleshooting section with common issues
4. Add architecture diagrams (images instead of ASCII)
5. Add links to related services and dependencies
6. Add runbook section for operations

## References

- [Backstage TechDocs](https://backstage.io/docs/features/techdocs/)
- [MkDocs Documentation](https://www.mkdocs.org/)
- [TechDocs Core Plugin](https://github.com/backstage/backstage/tree/master/plugins/techdocs)
