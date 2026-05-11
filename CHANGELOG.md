# Changelog

## [0.1.0] — 2026-05-11

Initial release of **paperclip-stack** — a self-hosted Docker Compose stack for [Paperclip AI](https://github.com/MinuteCode/paperclip) and its agent backends.

### What's included

- **Paperclip AI** — main chat UI, running in authenticated mode with Better Auth
- **Hermes Agent** — LLM gateway (Anthropic, OpenAI, OpenRouter, local Ollama, and others)
- **Hermes Dashboard** — agent monitoring interface
- **Hermes WebUI** — Hermes chat interface
- **PiClaw** — self-hosted Pi coding agent workspace (fork of pi.dev)

### Highlights

- Pre-built image published to `ghcr.io/codedmind/paperclip-stack` — no build required to get started
- Hermes config fully driven by `.env` — no interactive setup wizard on first boot
- All state stored in bind-mounted directories — easy to inspect, back up, and restore
- All ports default to `127.0.0.1` (localhost only) — opt-in LAN exposure per service
- GitHub Actions CI/CD: pushes to `main` publish `:latest`; version tags publish semver tags
