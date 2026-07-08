# syntax=docker/dockerfile:1.20
# Build Paperclip from source instead of pulling a prebuilt image.
# Defaults are pinned for reproducibility and can be overridden with build args.

ARG NODE_IMAGE=node:lts-trixie-slim@sha256:366fdef91728b1b7fa18c84fba63b6e79ed77b7e10cc206878e9705da4d7b169
ARG PAPERCLIP_REPO=https://github.com/paperclipai/paperclip.git
# v2026.707.0 release commit
ARG PAPERCLIP_REF=390627b46eb333309d357004384b220ecf8a65af
ARG CLAUDE_CODE_VERSION=2.1.204
ARG OPENAI_CODEX_VERSION=0.143.0
ARG OPENCODE_AI_VERSION=1.17.15
ARG GEMINI_CLI_VERSION=0.49.0
ARG PI_CODING_AGENT_VERSION=0.80.3

FROM ${NODE_IMAGE} AS base
ARG USER_UID=1000
ARG USER_GID=1000

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates gosu curl gh git wget ripgrep python3 \
  && rm -rf /var/lib/apt/lists/* \
  && corepack enable

# Remap the existing node user to the requested UID/GID and use /paperclip as HOME.
RUN usermod -u $USER_UID --non-unique node \
  && groupmod -g $USER_GID --non-unique node \
  && usermod -g $USER_GID -d /paperclip node

# ------------------------------------------------------------------------------
# Fetch the Paperclip source.
# Override PAPERCLIP_REF to pin another release tag or commit SHA.
# ------------------------------------------------------------------------------
FROM base AS source
ARG PAPERCLIP_REPO
ARG PAPERCLIP_REF
WORKDIR /app
RUN git init . \
  && git remote add origin "$PAPERCLIP_REPO" \
  && git fetch --depth 1 origin "$PAPERCLIP_REF" \
  && git checkout FETCH_HEAD

# ------------------------------------------------------------------------------
# Install dependencies.
# ------------------------------------------------------------------------------
FROM base AS deps
WORKDIR /app
COPY --from=source /app /app
RUN pnpm install --frozen-lockfile

# ------------------------------------------------------------------------------
# Build the Paperclip server and UI.
# ------------------------------------------------------------------------------
FROM base AS build
WORKDIR /app
COPY --from=deps /app /app
RUN pnpm --filter @paperclipai/ui build
RUN pnpm --filter @paperclipai/plugin-sdk build
RUN pnpm --filter @paperclipai/server build
RUN test -f server/dist/index.js || (echo "ERROR: server build output missing" && exit 1)
# Do not ship the cloned repository metadata in the runtime image.
RUN rm -rf .git

# ------------------------------------------------------------------------------
# Production image.
# ------------------------------------------------------------------------------
FROM base AS production
ARG USER_UID=1000
ARG USER_GID=1000
ARG PAPERCLIP_REPO
ARG PAPERCLIP_REF
ARG CLAUDE_CODE_VERSION
ARG OPENAI_CODEX_VERSION
ARG OPENCODE_AI_VERSION
ARG GEMINI_CLI_VERSION
ARG PI_CODING_AGENT_VERSION
WORKDIR /app
COPY --chown=node:node --from=build /app /app

LABEL org.opencontainers.image.source="$PAPERCLIP_REPO" \
      org.opencontainers.image.revision="$PAPERCLIP_REF" \
      paperclip.source.ref="$PAPERCLIP_REF"

# Install the agent CLIs bundled in the upstream image plus the pi CLI used here.
RUN npm install --global --omit=dev \
    @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
    @openai/codex@${OPENAI_CODEX_VERSION} \
    opencode-ai@${OPENCODE_AI_VERSION} \
    @google/gemini-cli@${GEMINI_CLI_VERSION} \
  && npm install -g --ignore-scripts @earendil-works/pi-coding-agent@${PI_CODING_AGENT_VERSION} \
  && apt-get update \
  && apt-get install -y --no-install-recommends openssh-client jq \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /paperclip \
  && chown node:node /paperclip \
  && printf '%s\n' '#!/bin/sh' 'cd /app' 'exec node cli/node_modules/tsx/dist/cli.mjs cli/src/index.ts "$@"' > /usr/local/bin/paperclipai \
  && chmod +x /usr/local/bin/paperclipai

COPY --from=source /app/scripts/docker-entrypoint.sh /usr/local/bin/
COPY --chown=node:node scripts/paperclip-init.mjs scripts/docker-start.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/paperclip-init.mjs /usr/local/bin/docker-start.sh

ENV NODE_ENV=production \
  HOME=/paperclip \
  HOST=0.0.0.0 \
  PORT=3100 \
  SERVE_UI=true \
  PAPERCLIP_HOME=/paperclip \
  PAPERCLIP_INSTANCE_ID=default \
  USER_UID=${USER_UID} \
  USER_GID=${USER_GID} \
  PAPERCLIP_CONFIG=/paperclip/instances/default/config.json \
  PAPERCLIP_DEPLOYMENT_MODE=authenticated \
  PAPERCLIP_DEPLOYMENT_EXPOSURE=public \
  OPENCODE_ALLOW_ALL_MODELS=true \
  GEMINI_SANDBOX=false

EXPOSE 3100

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["/usr/local/bin/docker-start.sh"]
