# paperclip-stack

A self-hosted Docker Compose stack for [Paperclip AI](https://github.com/MinuteCode/paperclip) and its agent backends. Paperclip is the central hub — this repo bundles locally-deployable services (Hermes, PiClaw/pi.dev, and others as they land) into a single compose file so you can run the full stack with one command.

## Services

| Service | Port | Description |
|---|---|---|
| Paperclip | `3100` | Main Paperclip UI |
| Hermes Gateway | `8642` | Internal LLM gateway (localhost only) |
| Hermes Dashboard | `9119` | Hermes agent monitoring |
| Hermes WebUI | `8787` | Hermes chat interface |
| PiClaw | `8080` | Pi coding agent workspace |

All ports bind to `127.0.0.1` by default (localhost only). See [Exposing services on the LAN](#exposing-services-on-the-lan) to change this.

---

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) with the Compose plugin (v2)
- `openssl` (to generate a secret — available on Linux/macOS; on Windows use Git Bash or WSL)

---

## Quick start

### Option A — Use the pre-built image (no build required)

```bash
git clone https://github.com/codedmind/paperclip-stack.git
cd paperclip-stack
cp .env.sample .env
```

Edit `.env` — fill in every field marked **required**:

| Variable | How to fill it in |
|---|---|
| `BETTER_AUTH_SECRET` | Run: `openssl rand -base64 32` and paste the output |
| `PAPERCLIP_PUBLIC_URL` | URL you'll use to open Paperclip (e.g. `http://localhost:3100`) |
| `BETTER_AUTH_URL` | Same value as `PAPERCLIP_PUBLIC_URL` |
| `API_SERVER_KEY` | Any string ≥ 8 characters — secures the Hermes gateway |
| `ANTHROPIC_API_KEY` | Your Anthropic API key (only needed to use Hermes) |
| `HERMES_MODEL` | Model to use (e.g. `qwen2.5-coder:32b`) |
| `HERMES_PROVIDER` | Provider type (e.g. `custom` for a local Ollama instance) |
| `HERMES_BASE_URL` | Your inference endpoint (e.g. `http://192.168.1.10:11434/v1`) |
| `HERMES_CONTEXT_LENGTH` | Model context window in tokens (e.g. `32768`) |
| `HERMES_TERMINAL_BACKEND` | Terminal backend (use `local`) |

Then start the stack:

```bash
mkdir -p paperclip-home hermes-home hermes-cli-home piclaw-home piclaw-workspace
docker compose up -d
```

Docker will pull `ghcr.io/codedmind/paperclip-stack:latest` automatically — no build needed.

---

### Option B — Build the image locally

Same steps as above, but start with:

```bash
docker compose up -d --build
```

This builds the `paperclip-stack` image from source before starting. Use this if you've made changes to the `Dockerfile` or `start.sh`.

---

### After starting

Open in your browser:

- Paperclip: http://localhost:3100
- Hermes WebUI: http://localhost:8787
- Hermes Dashboard: http://localhost:9119
- PiClaw: http://localhost:8080

---

## Configuration reference

All configuration lives in `.env`. The `.env.sample` file lists every available variable with comments.

### Required variables

| Variable | Description |
|---|---|
| `BETTER_AUTH_SECRET` | Secret used to sign Paperclip auth tokens |
| `PAPERCLIP_PUBLIC_URL` | Canonical public URL for Paperclip |
| `BETTER_AUTH_URL` | Must match `PAPERCLIP_PUBLIC_URL` |
| `API_SERVER_KEY` | Hermes gateway API key (min 8 chars) |
| `HERMES_MODEL` | Model identifier |
| `HERMES_PROVIDER` | Provider name (`custom`, `openai`, etc.) |
| `HERMES_BASE_URL` | Inference endpoint URL |
| `HERMES_CONTEXT_LENGTH` | Context window in tokens |
| `HERMES_TERMINAL_BACKEND` | Terminal backend (`local`) |

### Optional variables

| Variable | Default | Description |
|---|---|---|
| `USER_UID` / `USER_GID` | `1000` / `1000` | Match to your host user to avoid volume permission issues. Run `id -u && id -g` to check. |
| `ANTHROPIC_API_KEY` | — | Needed to use Hermes with Anthropic models |
| `IP_ADDRESS` | — | LAN IP to register with Paperclip's allowed-hostname list |
| `HERMES_WORKSPACE` | `/workspace` | Host directory mounted into Hermes WebUI |
| `HERMES_WEBUI_PASSWORD` | — | Password for the Hermes WebUI (set if exposing on LAN) |

For the full list see `.env.sample`.

---

## Exposing services on the LAN

By default every port binds to `127.0.0.1`. To expose a service on your network, set its bind variable in `.env`:

```
PAPERCLIP_BIND_HOST=0.0.0.0    # Paperclip UI     :3100
DASHBOARD_BIND_HOST=0.0.0.0    # Hermes dashboard :9119
WEBUI_BIND_HOST=0.0.0.0        # Hermes WebUI     :8787
PICLAW_WEB_BIND_HOST=0.0.0.0   # PiClaw           :8080
```

> The Hermes gateway (`:8642`) is always localhost-only and cannot be exposed.

If you expose Paperclip on a LAN IP, also update `PAPERCLIP_PUBLIC_URL`, `BETTER_AUTH_URL`, and `IP_ADDRESS` to use that IP instead of `localhost`.

---

## Persistent data

All state is stored in bind-mounted directories in the repo folder — no opaque Docker volumes.

| Host path | Description |
|---|---|
| `./paperclip-home` | Paperclip state and instances |
| `./hermes-home` | Hermes config, sessions, and state (shared by all Hermes services) |
| `./hermes-cli-home` | Hermes CLI data used by Paperclip |
| `./piclaw-home` | PiClaw config and state |
| `./piclaw-workspace` | PiClaw workspace (override with `PICLAW_WORKSPACE_PATH`) |

Back up any of these directories to preserve your data.

---

## Updating

To update to the latest images:

```bash
docker compose pull
docker compose up -d
```

To rebuild the Paperclip image from source:

```bash
docker compose up -d --build
```

---

## Hermes configuration

The Hermes config is generated from `hermes-config.yaml.template` on every boot using the `HERMES_*` variables from `.env`. To change the model, provider, or endpoint: edit `.env` and restart — no rebuild needed.

```bash
docker compose down && docker compose up -d
```

---

## PiClaw

[PiClaw](https://github.com/rcarmo/piclaw) is a standalone Pi coding agent with a web UI. It shares the Docker network but has no dependency on Hermes or Paperclip.

To point it at an existing project folder:

```bash
# In .env:
PICLAW_WORKSPACE_PATH=/path/to/your/project
```

Resource limits default to 2 CPU / 4 GB. Override in `.env` with `PICLAW_CPU_LIMITS` and `PICLAW_MEMORY_LIMITS`.

---

## Docker images

Pre-built images are published to the GitHub Container Registry on every push to `main` and on every version tag.

```bash
docker pull ghcr.io/codedmind/paperclip-stack:latest
docker pull ghcr.io/codedmind/paperclip-stack:0.1.0
```

---

## Architecture

```
hermes-config-init  (alpine — one-shot)
  └── renders hermes-config.yaml.template → ./hermes-home/config.yaml

hermes-agent  (nousresearch/hermes-agent:latest)
  ├── gateway run → :8642 (internal)
  ├── /opt/hermes          → hermes-agent-src (named volume — runtime binary)
  └── /home/hermes/.hermes → ./hermes-home

paperclip-stack  (ghcr.io/codedmind/paperclip-stack or local build)
  ├── /opt/hermes    ← hermes-agent-src
  ├── /data/hermes   ← ./hermes-cli-home
  └── /paperclip     ← ./paperclip-home

hermes-dashboard  (nousresearch/hermes-agent:latest) → :9119
hermes-webui  (ghcr.io/nesquena/hermes-webui) → :8787
piclaw  (ghcr.io/rcarmo/piclaw) → :8080
```

---

## Development

```bash
# Build and open a shell
docker build -t paperclip-stack:dev .
docker run --rm -it --entrypoint bash paperclip-stack:dev
```

### Releasing a new version

```bash
git tag v1.2.0
git push origin v1.2.0
```

The CI workflow builds and publishes `ghcr.io/codedmind/paperclip-stack` with tags `1.2.0`, `1.2`, `1`, and `latest`.

---

## Security notes

- Set a strong `API_SERVER_KEY` and `HERMES_WEBUI_PASSWORD` before exposing any port on the network
- `BETTER_AUTH_SECRET` must be kept secret — regenerate if compromised
- Consider pinning image digests in production (`image: ghcr.io/codedmind/paperclip-stack@sha256:...`)
