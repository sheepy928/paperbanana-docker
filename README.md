# PaperBanana Docker

Docker packaging for [PaperBanana](https://github.com/dwzhu-pku/PaperBanana), the reference-driven multi-agent framework for automated academic illustration generation.

> **Note:** This is an **unofficial** Docker image. It is not affiliated with, endorsed by, or maintained by the original PaperBanana authors. For the official project, visit [dwzhu-pku/PaperBanana](https://github.com/dwzhu-pku/PaperBanana).

## About PaperBanana

PaperBanana is a multi-agent system that uses vision-language models (VLMs) to automatically generate academic illustrations such as diagrams and plots. It supports Google/Gemini, OpenAI, Anthropic, and OpenRouter as model providers, and exposes a Streamlit web UI for interactive use.

## What This Repo Provides

- Pre-built Docker image published to GitHub Container Registry (GHCR)
- Docker Compose setup for single-command deployment
- Multi-architecture support (linux/amd64, linux/arm64)
- Automated CI/CD: image builds on push and daily upstream change detection
- Optional Cloudflare quick tunnel for public HTTPS access

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/sheepy928/paperbanana-docker.git
cd paperbanana-docker

# 2. Create your .env file and add at least one API key
cp .env.example .env

# 3. Create directories for persistent data
mkdir -p data results

# 4. Start with Docker Compose
docker compose up -d
```

The Streamlit UI will be available at [http://localhost:8080](http://localhost:8080).

See [DEPLOY.md](DEPLOY.md) for full configuration, volume mounts, GHCR images, Cloudflare tunnels, versioning, and troubleshooting.

## Pre-Built Images

Pull a pre-built image directly from GHCR instead of building locally:

```bash
docker pull ghcr.io/sheepy928/paperbanana-docker:latest
```

See [DEPLOY.md — Pull Pre-Built Image from GHCR](DEPLOY.md#pull-pre-built-image-from-ghcr) for version tags and compose integration.

## License

This Docker packaging repository is provided as-is. The upstream PaperBanana project has its own license — see the [official repository](https://github.com/dwzhu-pku/PaperBanana) for terms.
