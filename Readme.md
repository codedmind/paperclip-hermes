# paperclip-hermes

Docker image that bundles [Paperclip AI](https://github.com/MinuteCode/paperclip) with [Hermes Agent](https://github.com/NousResearch/hermes-agent).

Runs Paperclip and Hermes in a single container, with [Hermes Dashboard](https://github.com/NousResearch/hermes-agent) and [Hermes WebUI](https://github.com/nesquena/hermes-webui) as companion services via Docker Compose.

## Features

- Paperclip AI installed globally
- Hermes Agent installed under `/opt/hermes`
- Hermes gateway running on port `8642` (for WebUI and Dashboard)
- Persistent Paperclip data under `/paperclip`
- Persistent Hermes config under `/data/hermes`

## Services

| Service | Port | Description |
|---|---|---|
| Paperclip | `3100` | Main Paperclip UI |
| Hermes Gateway | `8642` | Internal — used by Dashboard and WebUI |
| Hermes Dashboard | `9119` | Hermes agent dashboard |
| Hermes WebUI | `8787` | Hermes chat interface |

## Quick start

```bash
cp .env.sample .env
# Edit .env — set ANTHROPIC_API_KEY if you want to use Hermes
docker compose up -d
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
| `ANTHROPIC_API_KEY` | unset | Needed to use Hermes (not required to start) |
| `API_SERVER_KEY` | unset | Gateway API key — required for gateway mode (min 8 chars) |
| `IP_ADDRESS` | unset | Optional hostname/IP to register with Paperclip |
| `HERMES_MODEL` | unset | Optional Hermes model override |
| `HERMES_INFERENCE_PROVIDER` | unset | Optional Hermes provider override |
| `HERMES_WORKSPACE` | `~/workspace` | Local directory mounted into Hermes WebUI |

## Persistent data

| Path | Description |
|---|---|
| `/paperclip` | Paperclip data (shared with Dashboard and WebUI) |
| `/data/hermes` | Hermes config and state |

Use Docker named volumes (default in `docker-compose.yml`) or bind mounts to persist data across restarts.

## Hermes configuration

On first boot, the image seeds a minimal Hermes config into `$HERMES_HOME/config.yaml` to prevent the interactive setup wizard from running. You can override it by mounting your own config:

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
# Second profile — copy compose and point to different volumes
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

This image downloads Hermes Agent during build time. For reproducible builds, pin the Hermes Agent reference to a specific tag or commit.

Recommended hardening:

- Pin the base image by digest
- Pin the `paperclipai` npm version
- Avoid `curl | bash` from a moving branch
- Add CI checks for Docker builds and shell scripts
