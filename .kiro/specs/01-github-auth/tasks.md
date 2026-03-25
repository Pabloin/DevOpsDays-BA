# Implementation Plan: GitHub Auth

## Overview

Wire GitHub OAuth into the existing Backstage portal alongside the guest provider. Four files change: `backend/src/index.ts`, `app-config.yaml`, `app-config.production.yaml`, and `packages/app/src/App.tsx`. Tests cover the resolver logic and the sign-in page rendering.

## Tasks

- [x] 1. Register GitHub provider module in backend
  - Add `backend.add(import('@backstage/plugin-auth-backend-module-github-provider'))` after the existing guest provider line in `packages/backend/src/index.ts`
  - Keep the existing guest provider import unchanged
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 2. Update `app-config.yaml` with GitHub auth section
  - Add `auth.environment: development` above the existing `auth.providers` key
  - Add `auth.providers.github.development` block with `clientId: ${AUTH_GITHUB_CLIENT_ID}` and `clientSecret: ${AUTH_GITHUB_CLIENT_SECRET}`
  - Retain the existing `auth.providers.guest: {}` entry
  - _Requirements: 2.1, 2.2, 2.3_

- [x] 3. Update `app-config.production.yaml` with GitHub auth section
  - Add `auth.environment: production` above the existing `auth.providers` key
  - Add `auth.providers.github.production` block with `clientId: ${AUTH_GITHUB_CLIENT_ID}` and `clientSecret: ${AUTH_GITHUB_CLIENT_SECRET}`
  - Retain the existing `auth.providers.guest: {}` entry
  - _Requirements: 5.1, 5.2, 5.3_

- [x] 4. Add `SignInPage` with both providers to `App.tsx`
  - Import `githubAuthApiRef` from `@backstage/core-plugin-api` and `SignInPage` from `@backstage/plugin-auth`
  - Add a `SignInPage` extension override to the `createApp` call configured with `providers: [githubAuthApiRef, 'guest']`
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

- [x] 5. Write resolver unit tests
  - Create `packages/backend/src/auth.github.resolver.test.ts`
  - Test success path: mock `signInWithCatalogUser` returning a known entity ref, assert resolver returns it (_Requirements: 4.1, 4.2_)
  - Test fallback path: mock `signInWithCatalogUser` throwing `NotFoundError`, assert returned token `sub` is `user:default/<login>` (_Requirements: 4.3_)
  - _Requirements: 4.1, 4.2, 4.3_

  - [ ]* 5.1 Write property test for resolver round-trip (Property 4)
    - Tag: `// Feature: github-auth, Property 4: Catalog resolver round-trip for known users`
    - Use `fc.record({ login: fc.string({ minLength: 1 }), entityRef: fc.string({ minLength: 1 }) })` with `numRuns: 100`
    - Mock catalog with a User entity annotated with the generated login, assert returned ref matches
    - **Validates: Requirements 4.1, 4.2**

  - [ ]* 5.2 Write property test for resolver fallback (Property 5)
    - Tag: `// Feature: github-auth, Property 5: Resolver fallback for unknown users`
    - Use `fc.string({ minLength: 1 })` for arbitrary GitHub logins with `numRuns: 100`
    - Mock catalog returning `NotFoundError`, assert `sub` claim equals `user:default/${login}`
    - **Validates: Requirements 4.3**

- [x] 6. Write frontend sign-in page render tests
  - Create `packages/app/src/SignInPage.test.tsx`
  - Render the app with no token using `@backstage/frontend-test-utils`, assert both "Sign in with GitHub" button and "Continue as Guest" option are present
  - Assert main app content is not rendered when unauthenticated
  - _Requirements: 3.2, 3.3_

  - [ ]* 6.1 Write property test for sign-in page renders both providers (Property 2)
    - Tag: `// Feature: github-auth, Property 2: Sign-in page renders both providers for all unauthenticated routes`
    - Use `fc.webPath()` with `numRuns: 100`
    - For each route, render app with no token and assert both GitHub button and guest option are present
    - **Validates: Requirements 3.2, 3.3**

  - [ ]* 6.2 Write property test for OAuth error surfaces to user (Property 3)
    - Tag: `// Feature: github-auth, Property 3: OAuth error surfaces to the user`
    - Use `fc.oneof(fc.string(), fc.constant('NetworkError'), fc.constant('access_denied'))` with `numRuns: 100`
    - Mock `githubAuthApiRef.signIn` to throw with the generated error, assert error text is visible and retry control is present
    - **Validates: Requirements 3.7**

- [ ] 7. Checkpoint — ensure all tests pass
  - Run `yarn test` from `backstage-portal/` and confirm all tests pass. Ask the user if any questions arise.
