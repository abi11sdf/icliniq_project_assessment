# ─── Stage 1: Builder ───────────────────────────────────
# Install ALL dependencies (including devDependencies for tests/lint)
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files first — Docker caches this layer
# If package.json didn't change, npm install won't re-run
COPY app/package*.json ./

RUN npm ci --include=dev

# Copy source code
COPY app/ .

# Run lint and tests inside the build — fails the build if they fail
RUN npm run lint
RUN npm test

# ─── Stage 2: Production ────────────────────────────────
# Fresh slim image — no dev tools, no test files, smaller attack surface
FROM node:20-alpine AS production

# Security: don't run as root
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy only package files and install PRODUCTION deps only
COPY app/package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Copy only the application source (not test files)
COPY app/server.js ./

# Set ownership to non-root user
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Cloud Run injects PORT env var — must listen on this
EXPOSE 8080

# Use node directly (not npm) — npm swallows signals, node handles SIGTERM cleanly
CMD ["node", "server.js"]
