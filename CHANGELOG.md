# Changelog

## [0.1.2] — 2026-05-13

### Fixed

- Add `@openai/codex` to global npm installs — Paperclip was failing to find the `codex` CLI at runtime
- Add `@anthropic-ai/claude-code` to global npm installs — pre-installs Claude CLI so Paperclip can find it without auto-install fallback

## [0.1.1] — 2026-05-11

### Fixed

- `HERMES_CONTEXT_LENGTH` default raised to `65536` (64K) — Hermes Agent requires a minimum of 64K and refused to start with the previous default of 32K
- Docker network renamed from `hermes-net` to `paperclip-stack` for consistency
- Readme: Option B (build locally) was missing the `git clone` step

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
