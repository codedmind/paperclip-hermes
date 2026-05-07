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

| Service | Port | Description |
|---|---|---|
| Paperclip | `3100` | Main Paperclip UI |
| Hermes Gateway | `8642` | API server for Dashboard and WebUI |
| Hermes Dashboard | `9119` | Hermes agent dashboard |
| Hermes WebUI | `8787` | Hermes chat interface |

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
| `HERMES_MODEL` | unset | Optional Hermes model override |
| `HERMES_INFERENCE_PROVIDER` | unset | Optional Hermes provider override |
| `HERMES_WORKSPACE` | `~/workspace` | Local directory mounted into Hermes WebUI |

## Persistent data

| Volume | Description |
|---|---|
| `paperclip-data` | Paperclip state and instances |
| `hermes-data` | Hermes config, sessions, and state (shared across all services) |
| `hermes-agent-src` | Hermes binary — populated by hermes-agent, mounted read-only by Paperclip |

Use Docker named volumes (default) or bind mounts to persist data across restarts.

## Hermes configuration

On first boot, `start.sh` seeds a minimal Hermes config into `$HERMES_HOME/config.yaml` if one doesn't already exist. This prevents the interactive setup wizard from running when Paperclip calls the Hermes CLI.

You can override it by mounting your own config:

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
