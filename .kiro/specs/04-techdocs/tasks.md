# Tasks

## Task List

- [x] 1. Switch TechDocs generator to local mode
  - [x] 1.1 In `backstage-portal/app-config.yaml`, change `techdocs.generator.runIn` from `docker` to `local`

- [x] 2. Install mkdocs-techdocs-core in the backend Docker image
  - [x] 2.1 In `backstage-portal/packages/backend/Dockerfile`, add `RUN pip3 install mkdocs-techdocs-core --break-system-packages` before the `USER` instruction

- [x] 3. Add MkDocs source files for the portal component
  - [x] 3.1 Create `backstage-portal/mkdocs.yml` with `site_name`, `docs_dir: docs`, and `plugins: [techdocs-core]`
  - [x] 3.2 Create `backstage-portal/docs/index.md` with introductory portal documentation

- [x] 4. Annotate the portal catalog entity
  - [x] 4.1 In `backstage-portal/catalog-info.yaml`, add annotation `backstage.io/techdocs-ref: dir:.` under `metadata.annotations`

- [ ] 5. Verify end-to-end
  - [ ] 5.1 Run `yarn start` from `backstage-portal/`, open the portal, navigate to the `backstage-portal` component, and confirm the Docs tab renders without errors
