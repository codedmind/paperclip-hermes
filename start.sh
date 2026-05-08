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

# Inspect opencode's per-user SQLite DB and migrate only when needed.
# DB at $HOME/.local/share/opencode/opencode.db. Output of priming goes to a persistent
# log file (volume) because previous attempts showed that bash echoes and redirected
# stdout/stderr can disappear from `docker compose logs` after paperclipai onboard ran.
OPENCODE_DB="${PAPERCLIP_HOME}/.local/share/opencode/opencode.db"
OPENCODE_LOG="${PAPERCLIP_HOME}/.opencode_priming.log"
{
  printf '\n=== [%s] entrypoint priming pass ===\n' "$(date -Iseconds)"
  printf 'OPENCODE_DB=%s\n' "${OPENCODE_DB}"
  printf 'PAPERCLIP_HOME=%s HOME=%s USER=%s\n' "${PAPERCLIP_HOME}" "${HOME:-?}" "$(whoami)"
} >> "${OPENCODE_LOG}" 2>&1 || true

printf '[entrypoint] inspecting opencode DB at %s (priming log: %s)\n' "${OPENCODE_DB}" "${OPENCODE_LOG}"

_run_priming() {
  printf '[entrypoint]   running: gosu node env HOME=%s opencode models\n' "${PAPERCLIP_HOME}"
  if gosu node env HOME="${PAPERCLIP_HOME}" opencode models >> "${OPENCODE_LOG}" 2>&1; then
    printf '[entrypoint]   priming OK (output appended to %s)\n' "${OPENCODE_LOG}"
  else
    _ec=$?
    printf '[entrypoint]   WARNING: priming failed (exit=%s, see %s)\n' "${_ec}" "${OPENCODE_LOG}"
  fi
}

if [ ! -e "${OPENCODE_DB}" ]; then
  printf '[entrypoint]   state: file missing\n'
  _run_priming
else
  _db_size=$(stat -c%s "${OPENCODE_DB}" 2>/dev/null || echo "?")
  _db_owner=$(stat -c "%U:%G" "${OPENCODE_DB}" 2>/dev/null || echo "?")
  printf '[entrypoint]   state: file exists (size=%s bytes, owner=%s)\n' "${_db_size}" "${_db_owner}"
  if [ ! -s "${OPENCODE_DB}" ]; then
    printf '[entrypoint]   empty file — running migration\n'
    _run_priming
  else
    printf '[entrypoint]   DB looks populated — skipping priming\n'
  fi
fi

echo "[entrypoint] starting paperclipai as node"
exec gosu node env HOME="${PAPERCLIP_HOME}" PAPERCLIP_HOME="${PAPERCLIP_HOME}" HERMES_HOME="${HERMES_HOME}" HOST=0.0.0.0 PATH="${PATH}" paperclipai run --bind lan
