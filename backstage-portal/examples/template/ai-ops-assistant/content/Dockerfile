# Stage 1: build React frontend
FROM node:22-alpine AS frontend-builder
WORKDIR /app/frontend
COPY frontend/package.json ./
RUN yarn install --frozen-lockfile
COPY frontend/ ./
RUN yarn build

# Stage 2: production Node.js server
# Serves the built React app as static files + backend API on port 3001
FROM node:22-alpine
WORKDIR /app/backend
COPY backend/package.json ./
RUN yarn install --frozen-lockfile --production
COPY backend/ ./
# prompt.md is read at startup from the parent directory
COPY prompt.md /app/prompt.md
# Serve built frontend from public/
COPY --from=frontend-builder /app/frontend/dist ./public

EXPOSE 3001
CMD ["node", "index.js"]
