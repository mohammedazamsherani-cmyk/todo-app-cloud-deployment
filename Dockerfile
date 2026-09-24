# syntax=docker/dockerfile:1

# ========================================
# Multi-stage Dockerfile for Cloud Run
# ========================================
ARG NODE_VERSION=22.21.0-alpine3.21

# ---------- Base ----------
FROM node:${NODE_VERSION} AS base
WORKDIR /app

# ---------- Dependencies (all, for build/test) ----------
FROM base AS deps
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --no-audit --no-fund

# ---------- Test ----------
FROM deps AS test
COPY . .
ENV NODE_ENV=test
RUN npx vitest run

# ---------- Build ----------
FROM deps AS build
COPY . .
ENV NODE_ENV=production
RUN npm run build

# ---------- Production dependencies only ----------
FROM base AS prod-deps
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev --no-audit --no-fund

# ---------- Runtime ----------
FROM node:${NODE_VERSION} AS production
WORKDIR /app

ENV NODE_ENV=production \
    PORT=8080

# Run as the unprivileged "node" user shipped with the official image
COPY --from=prod-deps --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/dist ./dist
COPY --chown=node:node package.json ./

USER node
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${PORT}/health" > /dev/null || exit 1

CMD ["node", "dist/server.js"]
