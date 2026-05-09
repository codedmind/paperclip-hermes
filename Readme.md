# paperclip-hermes

Docker image that runs [Paperclip AI](https://github.com/MinuteCode/paperclip) with [Hermes Agent](https://github.com/NousResearch/hermes-agent) available as a CLI tool.

Paperclip integrates with Hermes via CLI. The Hermes binary is provided by the official `nousresearch/hermes-agent` image through a shared Docker volume — no need to bake it into the Paperclip image. [Hermes Dashboard](https://github.com/NousResearch/hermes-agent) and [Hermes WebUI](https://github.com/nesquena/hermes-webui) run as companion services.

## Architecture

```
hermes-agent  (nousresearch/hermes-agent:latest)
  ├── gateway run → :8642
  ├── /opt/hermes          → hermes-agent-src (named volume — runtime binary)
  └── /home/hermes/.hermes → ./hermes-home (bind mount — config/state)

paperclip-hermes  (build local)
  ├── /opt/hermes    ← hermes-agent-src (named volume — CLI access)
  ├── /data/hermes   ← ./hermes-cli-home (bind mount)
  └── /paperclip     ← ./paperclip-home (bind mount)

hermes-dashboard  (nousresearch/hermes-agent:latest) → :9119
  └── /home/hermes/.hermes → ./hermes-home (shared bind mount)

hermes-webui  (ghcr.io/nesquena/hermes-webui) → :8787
  └── /home/hermeswebui/.hermes → ./hermes-home (shared bind mount)

piclaw  (ghcr.io/rcarmo/piclaw) → :8080  (standalone)
  ├── /config    ← ./piclaw-home (bind mount)
  └── /workspace ← ./piclaw-workspace (bind mount via driver_opts)
```

## Services

| Service | Port | Bind | Description |
|---|---|---|---|
| Paperclip | `3100` | `PAPERCLIP_BIND_HOST` | Main Paperclip UI |
| Hermes Gateway | `8642` | `127.0.0.1` (fixed) | Internal API — consumed by dashboard and WebUI over Docker network only |
| Hermes Dashboard | `9119` | `DASHBOARD_BIND_HOST` | Hermes agent dashboard |
| Hermes WebUI | `8787` | `WEBUI_BIND_HOST` | Hermes chat interface |
| PiClaw | `8080` | `PICLAW_WEB_BIND_HOST` | Pi Coding Agent workspace (standalone) |

All bind addresses default to `127.0.0.1`. Set the relevant variable to `0.0.0.0` in `.env` to expose a service on the LAN. The gateway is always localhost-only — there is no use case for exposing it to the host network.

## Quick start

```bash
cp .env.sample .env
# Edit .env — set API_SERVER_KEY and ANTHROPIC_API_KEY
mkdir -p paperclip-home hermes-home hermes-cli-home piclaw-home piclaw-workspace
docker compose up -d --build
```

Then open:

- Paperclip: http://localhost:3100
- Hermes WebUI: http://localhost:8787
- Hermes Dashboard: http://localhost:9119
- PiClaw: http://localhost:8080

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
| `PICLAW_WEB_BIND_HOST` | `127.0.0.1` | Bind address for PiClaw |
| `PICLAW_WEB_PORT` | `8080` | Port for PiClaw |
| `PICLAW_AUTOSTART` | `1` | Auto-start Pi agent on boot |
| `PUID` / `PGID` | `1000` | Host user UID/GID for PiClaw |
| `PICLAW_WORKSPACE_PATH` | `./piclaw-workspace` | Host path for PiClaw workspace |
| `PICLAW_CPU_LIMITS` | `2` | CPU limit for PiClaw container |
| `PICLAW_MEMORY_LIMITS` | `4G` | Memory limit for PiClaw container |

The five `HERMES_*` model/provider vars are consumed by `envsubst` in `start.sh` to render `hermes-config.yaml.template` into `$HERMES_HOME/config.yaml` at boot. Hermes itself does not read these env vars natively under `provider: custom`; substitution happens before Hermes loads. Change a value in `.env` and `docker compose down && docker compose up -d` — no rebuild needed.

## Persistent data

All data volumes are bind-mounted to local directories created at first run. Inspect or back up data directly from the host — no `docker volume` commands needed.

| Host path | Container path | Services | Description |
|---|---|---|---|
| `./hermes-home` | `/home/hermes/.hermes` | hermes-agent, hermes-dashboard, hermes-webui | Hermes config, sessions, and state (shared) |
| `./hermes-cli-home` | `/data/hermes` | paperclip-hermes | Hermes CLI data used by Paperclip |
| `./paperclip-home` | `/paperclip` | paperclip-hermes | Paperclip state and instances |
| `./piclaw-home` | `/config` | piclaw | PiClaw config and state |
| `./piclaw-workspace` | `/workspace` | piclaw | PiClaw workspace (path overridable via `PICLAW_WORKSPACE_PATH`) |
| `hermes-agent-src` *(named volume)* | `/opt/hermes` | hermes-agent, paperclip-hermes, hermes-webui | Hermes binary — populated by the agent container at startup |

## Hermes configuration

`hermes-config.yaml.template` defines the structure; the five `HERMES_*` model/provider vars from `.env` fill the values. On every boot, `start.sh` runs `envsubst` over the template and writes `$HERMES_HOME/config.yaml` — overwriting whatever was there. This both prevents the interactive setup wizard and keeps the running config in sync with `.env`.

To change model, provider, base URL, context length, or terminal backend: edit `.env` and `docker compose down && docker compose up -d`. No rebuild required. If a required `HERMES_*` var is missing, `start.sh` aborts with a clear error.

For ad-hoc debugging you can still override the rendered file by bind-mounting your own:

```bash
docker run --rm -it \
  -p 3100:3100 \
  -v ./hermes-config.yaml:/data/hermes/config.yaml \
  -v ./paperclip-home:/paperclip \
  paperclip-hermes
```

## Multi-profile

To run multiple independent Hermes instances, use separate containers with distinct volumes:

```bash
# Work profile
docker run -d \
  --name hermes-work \
  -v ./hermes-home-work:/data/hermes \
  -p 127.0.0.1:8643:8642 \
  paperclip-hermes

# Personal profile
docker run -d \
  --name hermes-personal \
  -v ./hermes-home-personal:/data/hermes \
  -p 127.0.0.1:8644:8642 \
  paperclip-hermes
```

Each profile gets its own data directory, sessions, memories, and config. Do not share the same `hermes-home` directory between two running containers — concurrent writes are not supported.

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