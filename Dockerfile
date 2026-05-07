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
    ca-certificates \
    git \
    gosu \
    ripgrep \
    && rm -rf /var/lib/apt/lists/* \
    && corepack enable

# Align node user UID/GID with host to avoid permission issues on bind mounts
RUN usermod -u $USER_UID --non-unique node \
    && groupmod -g $USER_GID --non-unique node \
    && usermod -g $USER_GID -d /paperclip node

# Pre-seed minimal Hermes config so it never triggers the interactive setup wizard.
# Copied to $HERMES_HOME at runtime by start.sh if not already present.
COPY hermes-config.yaml /etc/hermes/config.yaml
RUN touch /etc/hermes/.env

# Install Paperclip (goes to /usr/local/bin, accessible by all users)
RUN npm install -g paperclipai

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
