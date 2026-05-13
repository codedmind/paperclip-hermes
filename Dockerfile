FROM node:lts-trixie-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_ENV=production
ENV PAPERCLIP_HOME=/paperclip
ENV HERMES_HOME=/data/hermes
ENV PAPERCLIP_INSTANCE_ID=default
ENV PAPERCLIP_DEPLOYMENT_MODE=authenticated
ENV PAPERCLIP_DEPLOYMENT_EXPOSURE=private

# System deps — cached unless base image changes
# gettext-base provides envsubst (used by start.sh to render hermes config from template)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gettext-base \
    git \
    gosu \
    python3 \
    ripgrep \
    && rm -rf /var/lib/apt/lists/* \
    && corepack enable

# Install Paperclip + OpenCode (goes to /usr/local/bin, accessible by all users).
# OpenCode is the adapter Paperclip uses for the `opencode_local` agent type. Without it pre-installed,
# Paperclip's auto-install path does NOT fire on headless runs and tasks fail with
# "Command not found in PATH: opencode".
RUN npm install -g paperclipai opencode-ai @openai/codex

# Hermes config template — rendered by start.sh (envsubst) into $HERMES_HOME/config.yaml at runtime.
# Values come from .env vars (HERMES_MODEL, HERMES_PROVIDER, HERMES_BASE_URL, HERMES_CONTEXT_LENGTH,
# HERMES_TERMINAL_BACKEND). Hermes itself does not read these env vars; substitution happens before Hermes loads.
COPY hermes-config.yaml.template /etc/hermes/config.yaml.template
RUN touch /etc/hermes/.env

RUN mkdir -p /paperclip /workspace \
    && chown -R node:node /paperclip /workspace

VOLUME ["/paperclip"]

WORKDIR /workspace

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 3100

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:3100').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["/start.sh"]
