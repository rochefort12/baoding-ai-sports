# syntax=docker/dockerfile:1.7
FROM node:24-bookworm-slim AS check
WORKDIR /app
COPY . .
# Executable array, without launching an alternate command-line shell.
RUN ["node", "--test"]
FROM node:24-bookworm-slim AS runtime
WORKDIR /app
COPY --from=check --chown=node:node /app /app
USER node
ENV NODE_ENV=production AI_GATEWAY_PORT=8091 NODE_OPTIONS=--max-old-space-size=384
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD ["node", "--input-type=module", "-e", "const r=await fetch('http://127.0.0.1:8091/healthz');process.exit(r.ok?0:1)"]
CMD ["node", "server.mjs"]
