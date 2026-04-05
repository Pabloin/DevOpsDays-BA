# Requirements: Organization Dropdown (`10-org-dropdown`)

## Goal

Simplify the scaffolder template form by replacing the complex RepoUrlPicker with a pre-filled organization dropdown, ensuring all scaffolded repos are created in `mvp-glaciar-org`.

## Functional Requirements

| Req | Title | Description |
|-----|-------|-------------|
| 1.1 | Organization dropdown | Replace RepoUrlPicker with a simple dropdown showing only `mvp-glaciar-org` |
| 1.2 | Pre-selected organization | Organization field defaults to `mvp-glaciar-org` |
| 1.3 | Repository name field | Separate text field for repository name, defaults to service name |
| 1.4 | Construct repoUrl | Build repoUrl from organization + repo name in publish step |
| 2.1 | Apply to AI Ops Assistant | Update the AI Ops Assistant template |
| 2.2 | Apply to Example template | Update the Example Node.js template |

## Non-Functional Requirements

| Req | Title | Description |
|-----|-------|-------------|
| 3.1 | User experience | Form should be simpler and more intuitive than RepoUrlPicker |
| 3.2 | Validation | Prevent users from creating repos in wrong organization |
| 3.3 | Backward compatible | Existing scaffolded repos continue to work |

## Acceptance Criteria

- [ ] AI Ops Assistant template shows organization dropdown (only mvp-glaciar-org)
- [ ] Repository name field defaults to service name
- [ ] Scaffolding creates repo in mvp-glaciar-org successfully
- [ ] Example Node.js template also updated
- [ ] E2E test: scaffold a new app and verify repo created in correct org
