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

# Hermes binary is provided via the hermes-agent-src volume
export PATH="/opt/hermes:${PATH}"

# Wait for the hermes-agent-src volume to be populated by the hermes-agent container
echo "[entrypoint] waiting for hermes binary at /opt/hermes/hermes..."
until [ -x "/opt/hermes/hermes" ]; do
  sleep 1
done
echo "[entrypoint] hermes binary ready"

# Seed Hermes config if not already present
if [ ! -f "${HERMES_HOME}/config.yaml" ]; then
  echo "[entrypoint] seeding default hermes config"
  mkdir -p "${HERMES_HOME}"
  cp /etc/hermes/config.yaml "${HERMES_HOME}/config.yaml"
  cp /etc/hermes/.env        "${HERMES_HOME}/.env"
fi

# Non-interactive onboard on first boot
if [ ! -d "${PAPERCLIP_HOME}/instances" ]; then
  echo "[entrypoint] first boot — running paperclipai onboard --yes"
  gosu node env HOME="${PAPERCLIP_HOME}" PAPERCLIP_HOME="${PAPERCLIP_HOME}" paperclipai onboard --yes || echo "[entrypoint] WARNING: onboard exited non-zero"
fi

# Always allow localhost (required for Docker port-mapped access)
gosu node env HOME="${PAPERCLIP_HOME}" PAPERCLIP_HOME="${PAPERCLIP_HOME}" paperclipai allowed-hostname localhost || true

# Register additional hostname if IP_ADDRESS is set
if [ -n "${IP_ADDRESS:-}" ]; then
  echo "[entrypoint] registering allowed-hostname ${IP_ADDRESS}"
  gosu node env HOME="${PAPERCLIP_HOME}" PAPERCLIP_HOME="${PAPERCLIP_HOME}" paperclipai allowed-hostname "${IP_ADDRESS}" || echo "[entrypoint] WARNING: allowed-hostname failed"
fi

echo "[entrypoint] starting paperclipai as node"
exec gosu node env HOME="${PAPERCLIP_HOME}" PAPERCLIP_HOME="${PAPERCLIP_HOME}" HERMES_HOME="${HERMES_HOME}" HOST=0.0.0.0 paperclipai run --bind lan
