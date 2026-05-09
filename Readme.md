# paperclip-hermes

Docker image that runs [Paperclip AI](https://github.com/MinuteCode/paperclip) with [Hermes Agent](https://github.com/NousResearch/hermes-agent) available as a CLI tool.

Paperclip integrates with Hermes via CLI. The Hermes binary is provided by the official `nousresearch/hermes-agent` image through a shared Docker volume — no need to bake it into the Paperclip image. [Hermes Dashboard](https://github.com/NousResearch/hermes-agent) and [Hermes WebUI](https://github.com/nesquena/hermes-webui) run as companion services.

## Architecture

```
hermes-agent  (nousresearch/hermes-agent:latest)
  ├── gateway run → :8642
  ├── /opt/hermes       → hermes-agent-src volume (binary)
  └── /home/hermes/.hermes → hermes-data volume (config/state)

paperclip-hermes  (build local)
  ├── /opt/hermes       ← hermes-agent-src volume (CLI access)
  ├── /data/hermes      ← hermes-data volume (shared config)
  └── /paperclip        ← paperclip-data volume

hermes-dashboard  (nousresearch/hermes-agent:latest) → :9119
hermes-webui      (ghcr.io/nesquena/hermes-webui)   → :8787
```

## Services

| Service | Port | Bind | Description |
|---|---|---|---|
| Paperclip | `3100` | `PAPERCLIP_BIND_HOST` | Main Paperclip UI |
| Hermes Gateway | `8642` | `127.0.0.1` (fixed) | Internal API — consumed by dashboard and WebUI over Docker network only |
| Hermes Dashboard | `9119` | `DASHBOARD_BIND_HOST` | Hermes agent dashboard |
| Hermes WebUI | `8787` | `WEBUI_BIND_HOST` | Hermes chat interface |

All bind addresses default to `127.0.0.1`. Set the relevant variable to `0.0.0.0` in `.env` to expose a service on the LAN. The gateway is always localhost-only — there is no use case for exposing it to the host network.

## Quick start

```bash
cp .env.sample .env
# Edit .env — set API_SERVER_KEY and ANTHROPIC_API_KEY
docker compose up -d --build
```

Then open:

- Paperclip: http://localhost:3100
- Hermes WebUI: http://localhost:8787
- Hermes Dashboard: http://localhost:9119

## Build only

```bash
docker build -t paperclip-hermes .
```

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `USER_UID` | `1000` | Host user UID — avoids volume permission issues |
| `USER_GID` | `1000` | Host user GID |
| `PAPERCLIP_HOME` | `/paperclip` | Paperclip data directory |
| `HERMES_HOME` | `/data/hermes` | Hermes config/data directory |
| `PAPERCLIP_INSTANCE_ID` | `default` | Paperclip instance name |
| `PAPERCLIP_DEPLOYMENT_MODE` | `authenticated` | Paperclip deployment mode |
| `PAPERCLIP_DEPLOYMENT_EXPOSURE` | `private` | Paperclip exposure setting |
| `API_SERVER_KEY` | unset | Gateway API key — required for gateway mode (min 8 chars) |
| `ANTHROPIC_API_KEY` | unset | Needed to use Hermes (not required to start) |
| `IP_ADDRESS` | unset | Optional hostname/IP to register with Paperclip |
| `HERMES_MODEL` | required | Model identifier rendered into Hermes config (e.g. `qwen2.5-coder:32b`) |
| `HERMES_PROVIDER` | required | Hermes provider name (e.g. `custom` for local Ollama) |
| `HERMES_BASE_URL` | required | Inference endpoint URL (e.g. `http://host:11434/v1`) |
| `HERMES_CONTEXT_LENGTH` | required | Model context window in tokens (e.g. `32768`) |
| `HERMES_TERMINAL_BACKEND` | required | Terminal backend used by Hermes (e.g. `local`) |
| `HERMES_WORKSPACE` | `~/workspace` | Local directory mounted into Hermes WebUI |
| `PAPERCLIP_BIND_HOST` | `127.0.0.1` | Bind address for Paperclip (:3100) |
| `DASHBOARD_BIND_HOST` | `127.0.0.1` | Bind address for Hermes Dashboard (:9119) |
| `WEBUI_BIND_HOST` | `127.0.0.1` | Bind address for Hermes WebUI (:8787) |

The five `HERMES_*` model/provider vars are consumed by `envsubst` in `start.sh` to render `hermes-config.yaml.template` into `$HERMES_HOME/config.yaml` at boot. Hermes itself does not read these env vars natively under `provider: custom`; substitution happens before Hermes loads. Change a value in `.env` and `docker compose down && docker compose up -d` — no rebuild needed.

## Persistent data

| Volume | Description |
|---|---|
| `paperclip-data` | Paperclip state and instances |
| `hermes-data` | Hermes config, sessions, and state (shared across all services) |
| `hermes-agent-src` | Hermes binary — populated by hermes-agent, mounted read-only by Paperclip |

Use Docker named volumes (default) or bind mounts to persist data across restarts.

## Hermes configuration

`hermes-config.yaml.template` defines the structure; the five `HERMES_*` model/provider vars from `.env` fill the values. On every boot, `start.sh` runs `envsubst` over the template and writes `$HERMES_HOME/config.yaml` — overwriting whatever was there. This both prevents the interactive setup wizard and keeps the running config in sync with `.env`.

To change model, provider, base URL, context length, or terminal backend: edit `.env` and `docker compose down && docker compose up -d`. No rebuild required. If a required `HERMES_*` var is missing, `start.sh` aborts with a clear error.

For ad-hoc debugging you can still override the rendered file by bind-mounting your own:

```bash
docker run --rm -it \
  -p 3100:3100 \
  -v ./hermes-config.yaml:/data/hermes/config.yaml \
  -v paperclip-data:/paperclip \
  paperclip-hermes
```

## Multi-profile

To run multiple independent Hermes instances, use separate containers with distinct volumes:

```bash
# Work profile
docker run -d \
  --name hermes-work \
  -v hermes-data-work:/data/hermes \
  -p 127.0.0.1:8643:8642 \
  paperclip-hermes

# Personal profile
docker run -d \
  --name hermes-work \
  -v hermes-data-work:/data/hermes \
  -p 127.0.0.1:8643:8642 \
  paperclip-hermes
```

Each profile gets its own data directory, sessions, memories, and config. Do not share the same `hermes-data` volume between two running containers — concurrent writes are not supported.

## Development

Run a shell inside the image:

```bash
docker build -t paperclip-hermes:dev .
docker run --rm -it --entrypoint bash paperclip-hermes:dev
```

## Security notes

Recommended hardening:

- Pin the base image by digest
- Pin the `paperclipai` npm version
- Pin `nousresearch/hermes-agent` to a specific tag or digest
- Add CI checks for Docker builds and shell scripts