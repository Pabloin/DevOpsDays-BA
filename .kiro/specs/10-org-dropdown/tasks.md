# Implementation Plan: Organization Dropdown (`10-org-dropdown`)

## Overview

Replace RepoUrlPicker with organization dropdown and repository name field in scaffolder templates.

## Tasks

- [x] 1. Update AI Ops Assistant template
  - [x] 1.1 Replace repoUrl parameter with owner + repo_name
  - [x] 1.2 Set owner as enum with only mvp-glaciar-org
  - [x] 1.3 Default repo_name to service_name
  - [x] 1.4 Update publish step to construct repoUrl
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1_

- [ ] 2. Update Example Node.js template
  - [ ] 2.1 Replace repoUrl parameter with owner + repo_name
  - [ ] 2.2 Set owner as enum with only mvp-glaciar-org
  - [ ] 2.3 Default repo_name to component name
  - [ ] 2.4 Update publish step to construct repoUrl
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.2_

- [ ] 3. Test locally
  - [ ] 3.1 Start Backstage locally: `yarn start`
  - [ ] 3.2 Navigate to Create page
  - [ ] 3.3 Verify organization dropdown shows only mvp-glaciar-org
  - [ ] 3.4 Verify repo name defaults to service name
  - _Requirements: 3.1_

- [ ] 4. E2E test in production
  - [ ] 4.1 Deploy to production
  - [ ] 4.2 Scaffold a test app (e.g., "test-org-dropdown")
  - [ ] 4.3 Verify repo created in mvp-glaciar-org
  - [ ] 4.4 Verify repo name matches input
  - [ ] 4.5 Clean up test repo
  - _Requirements: 3.2, 3.3_

- [ ] 5. Commit and merge
  - [ ] 5.1 Commit changes to feature/10-org-dropdown
  - [ ] 5.2 Create PR to main
  - [ ] 5.3 Merge after E2E verification
