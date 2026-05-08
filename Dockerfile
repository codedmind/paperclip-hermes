FROM node:lts-trixie-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_ENV=production
ENV PAPERCLIP_HOME=/paperclip
ENV HERMES_HOME=/data/hermes
ENV PAPERCLIP_INSTANCE_ID=default
ENV PAPERCLIP_DEPLOYMENT_MODE=authenticated
ENV PAPERCLIP_DEPLOYMENT_EXPOSURE=private

# System deps — cached unless base image changes
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    gosu \
    python3 \
    ripgrep \
    && rm -rf /var/lib/apt/lists/* \
    && corepack enable

# Install Paperclip (goes to /usr/local/bin, accessible by all users)
RUN npm install -g paperclipai

# Pre-seed minimal Hermes config so it never triggers the interactive setup wizard.
# Copied to $HERMES_HOME at runtime by start.sh if not already present.
COPY hermes-config.yaml /etc/hermes/config.yaml
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
