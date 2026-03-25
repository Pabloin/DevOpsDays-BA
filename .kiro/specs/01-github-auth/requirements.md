# Requirements Document

## Introduction

Add GitHub OAuth as a second authentication provider alongside the existing guest provider in Backstage. The sign-in page will offer both options: guest (zero-friction, anonymous, resolves to `user:default/guest`) and GitHub (real identity tied to a GitHub account). The current allow-all permission policy means both users get the same access — the goal is to demonstrate that GitHub login is possible while still allowing attendees to browse as guest.

This covers backend provider registration, app-config changes, and frontend sign-in page wiring.

## Glossary

- **Auth_Backend**: The Backstage backend auth plugin (`@backstage/plugin-auth-backend`) responsible for handling authentication flows.
- **GitHub_Provider**: The Backstage backend module `@backstage/plugin-auth-backend-module-github-provider` that implements GitHub OAuth.
- **Guest_Provider**: The Backstage backend module `@backstage/plugin-auth-backend-module-guest-provider` that provides anonymous guest access resolving to `user:default/guest`.
- **Sign_In_Page**: The Backstage frontend component that presents authentication options to unauthenticated users.
- **Catalog_Resolver**: The sign-in resolver function that maps a GitHub identity to a Backstage Catalog User entity.
- **OAuth_App**: A GitHub OAuth Application registered in GitHub with a client ID and client secret.
- **App_Config**: The `app-config.yaml` (and `app-config.production.yaml`) configuration files consumed by both frontend and backend at runtime.
- **Frontend_App**: The Backstage frontend created via `createApp` from `@backstage/frontend-defaults`.
- **Backend**: The Backstage backend created via `createBackend` from `@backstage/backend-defaults`.

---

## Requirements

### Requirement 1: Register Both Guest and GitHub OAuth Providers on the Backend

**User Story:** As a platform engineer, I want the backend to support both the guest provider and GitHub OAuth, so that attendees can browse anonymously while also demonstrating real GitHub-backed authentication.

#### Acceptance Criteria

1. THE Backend SHALL register `@backstage/plugin-auth-backend-module-guest-provider` as an auth module.
2. THE Backend SHALL register `@backstage/plugin-auth-backend-module-github-provider` as an auth module.
3. WHEN the Backend starts, THE Auth_Backend SHALL expose the GitHub OAuth callback endpoint at `http://localhost:7007/api/auth/github/handler/frame`.
4. WHEN the Backend starts, THE Auth_Backend SHALL expose the guest sign-in endpoint alongside the GitHub endpoint.

---

### Requirement 2: Configure Both Auth Providers in App_Config

**User Story:** As a platform engineer, I want both guest and GitHub OAuth configured in App_Config, so that both providers are available at runtime.

#### Acceptance Criteria

1. THE App_Config SHALL retain the `auth.providers.guest` section (empty object `{}`).
2. THE App_Config SHALL contain an `auth.providers.github` section with `clientId` and `clientSecret` fields resolved from environment variables `AUTH_GITHUB_CLIENT_ID` and `AUTH_GITHUB_CLIENT_SECRET`.
3. THE App_Config SHALL set `auth.environment` to `development` for local configuration.
4. IF `AUTH_GITHUB_CLIENT_ID` or `AUTH_GITHUB_CLIENT_SECRET` environment variables are absent at backend startup, THEN THE Auth_Backend SHALL fail to start and log a descriptive error message.

---

### Requirement 3: Display Both Sign-In Options on the Frontend

**User Story:** As a developer, I want to see both a guest sign-in option and a "Sign in with GitHub" button when I open the portal, so that I can choose between anonymous access and GitHub-backed identity.

#### Acceptance Criteria

1. THE Frontend_App SHALL include the `githubAuthApiRef` provider so that the GitHub OAuth API is available to all frontend plugins.
2. WHEN an unauthenticated user navigates to any portal page, THE Sign_In_Page SHALL display a "Sign in with GitHub" button.
3. WHEN an unauthenticated user navigates to any portal page, THE Sign_In_Page SHALL display a "Continue as Guest" option.
4. WHEN a user clicks "Sign in with GitHub", THE Sign_In_Page SHALL initiate the GitHub OAuth flow via a popup or redirect.
5. WHEN the OAuth flow completes successfully, THE Sign_In_Page SHALL redirect the user to the page they originally requested.
6. WHEN a user selects the guest option, THE Sign_In_Page SHALL sign the user in as `user:default/guest` without any OAuth flow.
7. IF the OAuth flow fails or is cancelled, THEN THE Sign_In_Page SHALL display a descriptive error message and allow the user to retry.

---

### Requirement 4: Resolve GitHub Identity to a Catalog User Entity

**User Story:** As a platform engineer, I want signed-in GitHub users resolved to Catalog User entities, so that Backstage features that depend on user identity (ownership, permissions) work correctly.

#### Acceptance Criteria

1. WHEN a user completes GitHub OAuth sign-in, THE Catalog_Resolver SHALL look up a Catalog User entity whose annotation `github.com/user-login` matches the authenticated GitHub login.
2. WHEN a matching Catalog User entity is found, THE Catalog_Resolver SHALL return that entity reference as the signed-in user's Backstage identity.
3. IF no matching Catalog User entity is found, THEN THE Catalog_Resolver SHALL sign the user in using their GitHub login as the user entity reference under the `default` namespace (permissive fallback for demo purposes).
4. THE Catalog_Resolver SHALL use the `signInWithCatalogUser` helper (or equivalent resolver from `@backstage/plugin-auth-backend`) to perform the entity lookup.

---

### Requirement 5: Production Config Carries Both Auth Providers

**User Story:** As a platform engineer, I want the production app-config to reference both guest and GitHub OAuth credentials, so that the deployed portal supports both authentication options.

#### Acceptance Criteria

1. THE `app-config.production.yaml` SHALL retain the `auth.providers.guest` section.
2. THE `app-config.production.yaml` SHALL contain an `auth.providers.github` section with `clientId` and `clientSecret` fields resolved from environment variables `AUTH_GITHUB_CLIENT_ID` and `AUTH_GITHUB_CLIENT_SECRET`.
3. THE `app-config.production.yaml` SHALL set `auth.environment` to `production`.
