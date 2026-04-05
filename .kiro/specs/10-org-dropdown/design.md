# Design: Organization Dropdown (`10-org-dropdown`)

## Overview

Replace the Backstage `RepoUrlPicker` UI field with simpler form fields: an organization dropdown (pre-filled with `mvp-glaciar-org`) and a repository name text field. This prevents users from accidentally creating repos in the wrong organization.

## Current Implementation

```yaml
properties:
  repoUrl:
    title: Repository location
    type: string
    ui:field: RepoUrlPicker
    ui:options:
      allowedHosts:
        - github.com
      allowedOwners:
        - mvp-glaciar-org
```

**Issues:**
- Complex UI component
- Users can still type wrong organization
- Not obvious that organization is restricted

## Proposed Implementation

```yaml
properties:
  owner:
    title: Organization
    type: string
    default: mvp-glaciar-org
    enum:
      - mvp-glaciar-org
    enumNames:
      - 'mvp-glaciar-org'
  repo_name:
    title: Repository name
    type: string
    default: ${{ parameters.service_name }}
```

**Benefits:**
- Simple dropdown (only one option)
- Pre-selected, can't be changed
- Repository name is separate, clear field
- Defaults to service name

## Implementation Steps

1. Update template parameters section
2. Update publish step to construct repoUrl from owner + repo_name
3. Test locally
4. Deploy and test E2E

## Files to Change

- `backstage-portal/examples/template/ai-ops-assistant/template.yaml`
- `backstage-portal/examples/template/template.yaml`
