FROM node:lts-trixie-slim

ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_ENV=production
ENV PAPERCLIP_HOME=/paperclip
ENV HERMES_HOME=/data/hermes
ENV PAPERCLIP_INSTANCE_ID=default
ENV PAPERCLIP_DEPLOYMENT_MODE=authenticated
ENV PAPERCLIP_DEPLOYMENT_EXPOSURE=private

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    build-essential \
    ca-certificates \
    curl \
    git \
    gosu \
    python3 \
    ripgrep \
    && rm -rf /var/lib/apt/lists/* \
    && corepack enable

# Align node user UID/GID with host to avoid permission issues on bind mounts
RUN usermod -u $USER_UID --non-unique node \
    && groupmod -g $USER_GID --non-unique node \
    && usermod -g $USER_GID -d /paperclip node

# Install Hermes to /opt/hermes (not /root) so the node user can access it.
# HOME must be exported so the piped bash subprocess inherits it.
RUN mkdir -p /opt/hermes \
    && export HOME=/opt/hermes \
    && curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash -s -- --skip-setup \
    && chmod -R a+rX /opt/hermes \
    && ln -sf /opt/hermes/.local/bin/hermes /usr/local/bin/hermes

# Pre-seed minimal Hermes config so it never triggers the interactive setup wizard.
# The model/provider can be overridden at runtime via HERMES_MODEL and
# HERMES_INFERENCE_PROVIDER env vars.
COPY hermes-config.yaml /etc/hermes/config.yaml
RUN touch /etc/hermes/.env

# Install Paperclip (goes to /usr/local/bin, accessible by all users)
RUN npm install -g paperclipai

RUN mkdir -p /paperclip /data/hermes /workspace \
    && chown -R node:node /paperclip /data/hermes /workspace

VOLUME ["/paperclip"]

WORKDIR /workspace

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 3100
EXPOSE 8642

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:3100').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["/start.sh"]
