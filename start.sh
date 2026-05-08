#!/usr/bin/env bash
set -euo pipefail

echo "[entrypoint] pid=$$ starting as $(id)"

export PAPERCLIP_HOME="${PAPERCLIP_HOME:-/paperclip}"
export HERMES_HOME="${HERMES_HOME:-/data/hermes}"
export HOME="${PAPERCLIP_HOME}"
export HOST="0.0.0.0"

# Remap node UID/GID to match host user at runtime — avoids volume permission issues
# Pattern from official Paperclip docker-entrypoint.sh
PUID="${USER_UID:-1000}"
PGID="${USER_GID:-1000}"
_changed=0
if [ "$(id -u node)" -ne "$PUID" ]; then
  echo "[entrypoint] updating node UID to $PUID"
  usermod -o -u "$PUID" node
  _changed=1
fi
if [ "$(id -g node)" -ne "$PGID" ]; then
  echo "[entrypoint] updating node GID to $PGID"
  groupmod -o -g "$PGID" node
  usermod -g "$PGID" node
  _changed=1
fi
if [ "$_changed" = "1" ]; then
  chown -R node:node "${PAPERCLIP_HOME}"
fi

# Hermes binary and its Python venv are provided via the hermes-agent-src volume
# .venv/bin must come first so that the hermes script's 'env python3' resolves to the
# venv interpreter that has all required packages (e.g. PyYAML)
export PATH="/opt/hermes/.venv/bin:/opt/hermes:${PATH}"

# Wait for the hermes-agent-src volume to be populated by the hermes-agent container
echo "[entrypoint] waiting for hermes binary at /opt/hermes/hermes..."
_elapsed=0
_max_wait=120
until [ -x "/opt/hermes/hermes" ]; do
  if [ "$_elapsed" -ge "$_max_wait" ]; then
    echo "[entrypoint] FATAL: hermes binary not ready after ${_max_wait}s — is hermes-agent running?"
    exit 1
  fi
  sleep 1
  ((_elapsed++))
done
echo "[entrypoint] hermes binary ready"

# Create wrapper so Paperclip finds hermes via standard PATH regardless of how it spawns subprocesses
cat > /usr/local/bin/hermes <<'WRAPPER'
#!/bin/bash
exec /opt/hermes/.venv/bin/python3 /opt/hermes/hermes "$@"
WRAPPER
chmod +x /usr/local/bin/hermes

# Always apply our hermes CLI config (hermes-cli-data is exclusive to paperclip-hermes)
# Render config.yaml from template — envsubst substitutes ${HERMES_*} from .env before Hermes loads.
# Hermes has no native env-var support for these fields under provider:custom, so substitution happens here.
echo "[entrypoint] rendering hermes CLI config from template"
: "${HERMES_MODEL:?HERMES_MODEL not set in .env}"
: "${HERMES_PROVIDER:?HERMES_PROVIDER not set in .env}"
: "${HERMES_BASE_URL:?HERMES_BASE_URL not set in .env}"
: "${HERMES_CONTEXT_LENGTH:?HERMES_CONTEXT_LENGTH not set in .env}"
: "${HERMES_TERMINAL_BACKEND:?HERMES_TERMINAL_BACKEND not set in .env}"
mkdir -p "${HERMES_HOME}"
envsubst < /etc/hermes/config.yaml.template > "${HERMES_HOME}/config.yaml"
cp /etc/hermes/.env        "${HERMES_HOME}/.env"
chown -R node:node "${HERMES_HOME}"

# Non-interactive onboard on first boot — --bind lan sets authenticated/private mode with LAN binding
# --yes alone forces local_trusted/loopback and ignores all env vars (upstream behaviour)
if [ ! -d "${PAPERCLIP_HOME}/instances" ]; then
  echo "[entrypoint] first boot — running paperclipai onboard --yes --bind lan"
  gosu node env HOME="${PAPERCLIP_HOME}" PAPERCLIP_HOME="${PAPERCLIP_HOME}" paperclipai onboard --yes --bind lan || echo "[entrypoint] WARNING: onboard exited non-zero"
fi

# Always allow localhost (required for Docker port-mapped access)
gosu node env HOME="${PAPERCLIP_HOME}" PAPERCLIP_HOME="${PAPERCLIP_HOME}" paperclipai allowed-hostname localhost || true

# Register additional hostname if IP_ADDRESS is set
if [ -n "${IP_ADDRESS:-}" ]; then
  echo "[entrypoint] registering allowed-hostname ${IP_ADDRESS}"
  gosu node env HOME="${PAPERCLIP_HOME}" PAPERCLIP_HOME="${PAPERCLIP_HOME}" paperclipai allowed-hostname "${IP_ADDRESS}" || echo "[entrypoint] WARNING: allowed-hostname failed"
fi

# Prime opencode's per-user SQLite DB at $HOME/.local/share/opencode/opencode.db.
# `opencode models` runs the schema migration on first invocation and is a fast no-op
# afterwards. We always run it instead of guarding with a file-exists check because
# Paperclip's adapter probe may leave an empty (un-migrated) opencode.db, which would
# fool a `[ ! -f ]` test and skip the priming — leaving the adapter with zero models.
echo "[entrypoint] priming opencode DB (idempotent)"
gosu node env HOME="${PAPERCLIP_HOME}" opencode models > /dev/null 2>&1 || \
  echo "[entrypoint] WARNING: opencode models priming failed"

echo "[entrypoint] starting paperclipai as node"
exec gosu node env HOME="${PAPERCLIP_HOME}" PAPERCLIP_HOME="${PAPERCLIP_HOME}" HERMES_HOME="${HERMES_HOME}" HOST=0.0.0.0 PATH="${PATH}" paperclipai run --bind lan
