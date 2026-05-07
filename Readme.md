# paperclip-hermes

Docker image that bundles [Paperclip AI](https://github.com/MinuteCode/paperclip) with [Hermes Agent](https://github.com/NousResearch/hermes-agent).

This image is intended to run Paperclip with Hermes available inside the same container.

## Features

- Paperclip AI installed globally
- Hermes Agent installed under `/opt/hermes`
- Persistent Paperclip data under `/paperclip`
- Persistent Hermes config under `/data/hermes`
- Exposes Paperclip on port `3100`

## Usage

### Build

```bash
docker build -t paperclip-hermes .
````

### Run

```bash
docker run --rm -it \
  -p 3100:3100 \
  -v paperclip-data:/paperclip \
  -v hermes-data:/data/hermes \
  paperclip-hermes
```

Then open:

```text
http://localhost:3100
```

## Environment variables

| Variable                    |           Default | Description                                     |
| --------------------------- | ----------------: | ----------------------------------------------- |
| `PAPERCLIP_HOME`            | `/data/paperclip` | Paperclip data directory                        |
| `HERMES_HOME`               |    `/data/hermes` | Hermes config/data directory                    |
| `IP_ADDRESS`                |             unset | Optional hostname/IP to register with Paperclip |
| `HERMES_MODEL`              |             unset | Optional Hermes model override                  |
| `HERMES_INFERENCE_PROVIDER` |             unset | Optional Hermes provider override               |

## Persistent data

The container uses two persistent directories:

```text
/paperclip
/data/hermes
```

Use Docker volumes or bind mounts to keep data across restarts.

## Hermes configuration

On first boot, the image seeds a minimal Hermes config into:

```text
/data/hermes/config.yaml
```

You can edit this file after the first run, or mount your own config.

Example:

```bash
docker run --rm -it \
  -p 3100:3100 \
  -v ./hermes-config.yaml:/data/hermes/config.yaml \
  -v paperclip-data:/paperclip \
  paperclip-hermes
```

## Development

Build locally:

```bash
docker build -t paperclip-hermes:dev .
```

Run shell:

```bash
docker run --rm -it --entrypoint bash paperclip-hermes:dev
```

## Security notes

This image downloads Hermes Agent during build time. For reproducible builds, pin the Hermes Agent reference to a specific tag or commit.

Recommended hardening:

* Pin the base image by digest
* Pin the `paperclipai` npm version
* Avoid `curl | bash` from a moving branch
* Run as a non-root user
* Add CI checks for Docker builds and shell scripts


