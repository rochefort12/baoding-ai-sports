# syntax=docker/dockerfile:1.7
FROM node:24-bookworm-slim AS build
WORKDIR /build
ARG NPM_REGISTRY=https://registry.npmjs.org
ENV npm_config_registry=${NPM_REGISTRY} npm_config_fetch_retries=5 npm_config_fetch_retry_mintimeout=3000 npm_config_fetch_retry_maxtimeout=15000
RUN --mount=type=cache,target=/root/.npm ["npm", "install", "--global", "pnpm@11.19.0"]
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN --mount=type=cache,target=/root/.local/share/pnpm/store \
    ["pnpm", "install", "--frozen-lockfile"]
COPY . .
# Public build setting paired with the local backend's disabled API encryption.
ARG VITE_APP_ENCRYPT=false
ENV VITE_APP_ENCRYPT=${VITE_APP_ENCRYPT}
RUN ["pnpm", "run", "typecheck"]
RUN ["pnpm", "exec", "vitest", "run"]
RUN ["pnpm", "run", "build:prod"]
FROM nginx:1.28-alpine AS runtime
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY --from=build --chown=101:101 /build/dist /usr/share/nginx/html
USER 101:101
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD ["wget", "--quiet", "--spider", "http://127.0.0.1:8080/healthz"]
ENTRYPOINT ["nginx", "-g", "daemon off;"]
