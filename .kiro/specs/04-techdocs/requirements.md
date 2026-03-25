# Requirements Document

## Introduction

Enable TechDocs in-app documentation for the Backstage portal demo. The goal is a minimal, working TechDocs setup that uses local generation (no Docker, no S3) so the Docs tab appears for the `backstage-portal` catalog entity. This is a demo-grade configuration — docs are generated and served directly from the container filesystem.

## Glossary

- **TechDocs**: Backstage's built-in documentation system that renders MkDocs-based markdown as browsable docs inside the portal.
- **Local_Generator**: The TechDocs generation mode where `mkdocs` runs directly on the host (or container) without Docker.
- **Local_Publisher**: The TechDocs publisher mode that stores and serves generated docs from the local filesystem.
- **mkdocs-techdocs-core**: A Python MkDocs plugin required by Backstage TechDocs for local generation.
- **Catalog_Entity**: A Backstage software catalog entry described by a `catalog-info.yaml` file.
- **techdocs-ref**: The `backstage.io/techdocs-ref` annotation on a Catalog_Entity that tells TechDocs where to find the MkDocs source.
- **Docs_Tab**: The "Docs" tab rendered in the Backstage UI for a Catalog_Entity that has a valid `techdocs-ref` annotation.
- **Portal_Component**: The `backstage-portal` Component entity defined in `backstage-portal/catalog-info.yaml`.

## Requirements

### Requirement 1: Switch TechDocs Generator to Local Mode

**User Story:** As a developer running the portal locally or in a container, I want TechDocs to generate docs without Docker, so that the demo works in any environment without a Docker-in-Docker setup.

#### Acceptance Criteria

1. THE `app-config.yaml` SHALL set `techdocs.generator.runIn` to `local`.
2. WHEN TechDocs generates documentation, THE Local_Generator SHALL invoke `mkdocs` directly on the host without spawning a Docker container.
3. IF `techdocs.generator.runIn` is set to `docker`, THEN THE System SHALL require Docker to be available, which is an unacceptable dependency for this demo.

---

### Requirement 2: Install mkdocs-techdocs-core Python Dependency

**User Story:** As a developer, I want the required Python package installed in the container image, so that local TechDocs generation succeeds without missing-dependency errors.

#### Acceptance Criteria

1. THE `backstage-portal/packages/backend/Dockerfile` SHALL include a `pip install mkdocs-techdocs-core` step so the package is available at generation time.
2. WHEN the backend container starts and TechDocs generation is triggered, THE Local_Generator SHALL find `mkdocs-techdocs-core` on the Python path and complete without error.
3. IF `mkdocs-techdocs-core` is not installed, THEN THE Local_Generator SHALL fail with a missing plugin error when attempting to build docs.

---

### Requirement 3: Add TechDocs Source Files to the Portal Repository

**User Story:** As a portal user, I want the `backstage-portal` component to have browsable documentation, so that I can see a working Docs tab for the portal itself.

#### Acceptance Criteria

1. THE repository SHALL contain a `backstage-portal/docs/index.md` file with introductory content about the portal.
2. THE repository SHALL contain a `backstage-portal/mkdocs.yml` file that references `techdocs-core` as a plugin and sets `docs_dir: docs`.
3. WHEN TechDocs processes the Portal_Component, THE Local_Generator SHALL read `mkdocs.yml` from the directory referenced by the `techdocs-ref` annotation and produce rendered HTML.

---

### Requirement 4: Annotate the Portal Catalog Entity

**User Story:** As a portal user, I want the `backstage-portal` catalog entity to show a Docs tab, so that I can navigate to its documentation from the component page.

#### Acceptance Criteria

1. THE `backstage-portal/catalog-info.yaml` SHALL include the annotation `backstage.io/techdocs-ref: dir:.` pointing to the repository root where `mkdocs.yml` lives.
2. WHEN the Catalog_Entity is loaded, THE Backstage_Catalog SHALL display a Docs tab for the Portal_Component.
3. WHEN a user clicks the Docs tab, THE TechDocs_Plugin SHALL trigger generation (if not cached) and render the documentation.

---

### Requirement 5: No External Infrastructure Dependencies

**User Story:** As a developer running the demo, I want TechDocs to work with zero external services, so that the demo is self-contained and portable.

#### Acceptance Criteria

1. THE `app-config.yaml` SHALL set `techdocs.publisher.type` to `local`.
2. THE `app-config.yaml` SHALL set `techdocs.builder` to `local`.
3. THE System SHALL require no S3 bucket, GCS bucket, or any cloud storage service for TechDocs to function.
4. THE System SHALL require no external CI/CD pipeline step to pre-generate documentation.
