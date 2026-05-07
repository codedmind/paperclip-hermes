#!/usr/bin/env bash
set -euo pipefail

echo "[worker] pid=$$ running as $(id)"

export HOME="${PAPERCLIP_HOME:-/paperclip}"
export PAPERCLIP_HOME="${PAPERCLIP_HOME:-/paperclip}"
export HERMES_HOME="${HERMES_HOME:-/data/hermes}"
export HOST="0.0.0.0"

# If no IP_ADDRESS to register, just start directly
if [ -z "${IP_ADDRESS:-}" ]; then
  echo "[worker] starting paperclipai run"
  exec paperclipai run
fi

# With IP_ADDRESS: start paperclipai in background, wait for it to be ready,
# register the hostname, then wait on the process
echo "[worker] starting paperclipai run (background, waiting to register hostname)"
paperclipai run &
PAPERCLIP_PID=$!

# Forward SIGTERM/SIGINT to the child process for graceful shutdown
trap 'kill -TERM $PAPERCLIP_PID 2>/dev/null; wait $PAPERCLIP_PID' TERM INT

# Wait for port 3100 to accept connections
RETRIES=0
MAX_RETRIES=30
echo "[worker] waiting for paperclipai to become ready on port 3100..."
until bash -c 'echo > /dev/tcp/127.0.0.1/3100' 2>/dev/null; do
  RETRIES=$((RETRIES + 1))
  if [ "$RETRIES" -ge "$MAX_RETRIES" ]; then
    echo "[worker] WARNING: paperclipai not ready after ${MAX_RETRIES}s, skipping allowed-hostname"
    break
  fi
  if ! kill -0 "$PAPERCLIP_PID" 2>/dev/null; then
    echo "[worker] ERROR: paperclipai exited before becoming ready"
    exit 1
  fi
  sleep 1
done

if [ "$RETRIES" -lt "$MAX_RETRIES" ]; then
  echo "[worker] registering allowed-hostname '${IP_ADDRESS}'"
  paperclipai allowed-hostname "${IP_ADDRESS}" || echo "[worker] WARNING: allowed-hostname registration failed"
fi

# Wait on paperclipai as the foreground process
wait $PAPERCLIP_PID
