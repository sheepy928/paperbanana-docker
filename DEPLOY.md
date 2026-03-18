# PaperBanana Docker — Deployment Guide

Production Docker setup for [PaperBanana](https://github.com/dwzhu-pku/PaperBanana), the reference-driven multi-agent framework for automated academic illustration generation.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Web-Based Setup Wizard](#web-based-setup-wizard)
- [Data Externalization](#data-externalization)
- [Docker Compose](#docker-compose)
- [Pull Pre-Built Image from GHCR](#pull-pre-built-image-from-ghcr)
- [Cloudflared HTTPS Tunnel](#cloudflared-https-tunnel)
- [Versioning](#versioning)
- [Building Locally](#building-locally)
- [Updating the Upstream Commit](#updating-the-upstream-commit)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

- Docker Engine 20.10+ (with BuildKit)
- Docker Compose v2+ (for compose workflows)
- At least one API key for a supported model provider (Google/Gemini, OpenAI, Anthropic, or OpenRouter)

---

## Quick Start

The fastest way to get running:

```bash
# 1. Clone this repo
git clone https://github.com/<your-org>/paperbanana-docker.git
cd paperbanana-docker

# 2. Create your .env file
cp .env.example .env
# Edit .env and add your API key(s)

# 3. Create directories for persistent data
mkdir -p data results

# 4. Start with Docker Compose
docker compose up -d

# 5. Open in browser
open http://localhost:8080
```

---

## Configuration

All configuration is managed through environment variables. Copy the example file and fill in your values:

```bash
cp .env.example .env
```

### Required Variables

| Variable | Description |
|---|---|
| `GOOGLE_API_KEY` | Google/Gemini API key (required if using Gemini models) |

### Optional Variables

| Variable | Default | Description |
|---|---|---|
| `OPENAI_API_KEY` | _(empty)_ | OpenAI API key |
| `ANTHROPIC_API_KEY` | _(empty)_ | Anthropic API key |
| `OPENROUTER_API_KEY` | _(empty)_ | OpenRouter unified API key |
| `GEMINI_BASE_URL` | _(empty)_ | Custom base URL for Gemini API (for third-party proxies) |
| `MAIN_MODEL_NAME` | `gemini-3.1-pro-preview` | Main VLM for planning/critique |
| `IMAGE_GEN_MODEL_NAME` | `gemini-3.1-flash-image-preview` | Image generation model |
| `ENABLE_CLOUDFLARED` | `false` | Enable public HTTPS tunnel |
| `STREAMLIT_PORT` | `8080` | Port for the Streamlit web UI |

### Alternative: Config File

Instead of environment variables, you can bind-mount a custom `model_config.yaml`:

```bash
mkdir -p configs
cat > configs/model_config.yaml <<'EOF'
defaults:
  main_model_name: "gemini-3.1-pro-preview"
  image_gen_model_name: "gemini-3.1-flash-image-preview"

api_keys:
  google_api_key: "your-key-here"
  openai_api_key: ""
  anthropic_api_key: ""
  openrouter_api_key: ""
EOF

docker run -v ./configs:/app/configs ...
```

When a `configs/model_config.yaml` is mounted, the entrypoint will use it as-is and skip generating one from environment variables.

---

## Web-Based Setup Wizard

If the container starts **without any API keys** (no `.env` file, no environment variables, no bind-mounted config), it automatically presents a setup wizard in the browser instead of the main application.

### How It Works

1. The entrypoint detects that all API key values are empty.
2. A lightweight Streamlit setup page is served on the same port (default `8080`).
3. The user enters at least one API key and optional model settings, then clicks **Save & Launch**.
4. The wizard writes `configs/model_config.yaml` inside the container.
5. The entrypoint detects the change, stops the wizard, and starts the real PaperBanana app.

No upstream code is modified — the wizard is a separate Streamlit script that only manages the config file.

### Zero-Config Launch

This means you can start the container with no configuration at all:

```bash
docker run -d --name paperbanana -p 8080:8080 \
    -v "$(pwd)/results:/app/results" \
    paperbanana:latest
```

Then open `http://localhost:8080` and fill in your keys through the web UI.

### Notes

- If you **do** provide API keys via `.env` or environment variables, the wizard is skipped entirely and the app starts immediately.
- The wizard writes to the container's filesystem. To persist keys across container restarts, bind-mount the configs directory:

```bash
-v "$(pwd)/configs:/app/configs"
```

---

## Data Externalization

The container uses three directories that should be mounted as volumes to persist data across container restarts and upgrades.

### Volume Mount Points

| Host Path | Container Path | Purpose |
|---|---|---|
| `./data` | `/app/data` | PaperBananaBench dataset (optional) |
| `./results` | `/app/results` | Generated diagrams and outputs |
| `./configs` | `/app/configs` | Custom `model_config.yaml` (optional) |

### Downloading the Dataset

The PaperBananaBench dataset is optional — without it, the Retriever Agent's few-shot learning is skipped and the pipeline still works.

To download it:

```bash
# Install huggingface-hub CLI if you don't have it
pip install huggingface-hub

# Download the dataset into ./data/PaperBananaBench/
huggingface-cli download dwzhu/PaperBananaBench \
    --repo-type dataset \
    --local-dir ./data/PaperBananaBench
```

Expected structure after download:

```
data/
└── PaperBananaBench/
    ├── diagram/
    │   ├── images/
    │   ├── pdfs/
    │   ├── test.json
    │   └── ref.json
    └── plot/
```

### Example: docker run with Volumes

```bash
docker run -d \
    --name paperbanana \
    -p 8080:8080 \
    -e GOOGLE_API_KEY="your-api-key" \
    -v "$(pwd)/data:/app/data" \
    -v "$(pwd)/results:/app/results" \
    paperbanana:latest
```

### Example: docker run with All Options

```bash
docker run -d \
    --name paperbanana \
    -p 8080:8080 \
    -e GOOGLE_API_KEY="your-api-key" \
    -e MAIN_MODEL_NAME="gemini-3.1-pro-preview" \
    -e IMAGE_GEN_MODEL_NAME="gemini-3.1-flash-image-preview" \
    -e ENABLE_CLOUDFLARED="true" \
    -v "$(pwd)/data:/app/data" \
    -v "$(pwd)/results:/app/results" \
    -v "$(pwd)/configs:/app/configs" \
    --restart unless-stopped \
    paperbanana:latest
```

---

## Docker Compose

The recommended way to run PaperBanana in production.

### Start

```bash
docker compose up -d
```

### View Logs

```bash
docker compose logs -f paperbanana
```

### Stop

```bash
docker compose down
```

### Rebuild After Changes

```bash
docker compose build --no-cache
docker compose up -d
```

---

## Pull Pre-Built Image from GHCR

If the GitHub Action has published an image, pull it directly:

```bash
# Pull latest
docker pull ghcr.io/<your-org>/paperbanana-docker:latest

# Pull a specific version
docker pull ghcr.io/<your-org>/paperbanana-docker:69e6bd9-01

# Run directly from the pulled image
docker run -d \
    --name paperbanana \
    -p 8080:8080 \
    -e GOOGLE_API_KEY="your-api-key" \
    -v "$(pwd)/data:/app/data" \
    -v "$(pwd)/results:/app/results" \
    ghcr.io/<your-org>/paperbanana-docker:latest
```

To use the GHCR image with docker compose, update the `image` field in `docker-compose.yml`:

```yaml
services:
  paperbanana:
    image: ghcr.io/<your-org>/paperbanana-docker:latest
    # Remove or comment out the 'build:' section
```

---

## Cloudflared HTTPS Tunnel

Cloudflared creates a free, temporary public HTTPS URL for your PaperBanana instance — useful for sharing with collaborators or accessing from mobile devices without port forwarding or DNS setup.

### Enable via Environment Variable

```bash
docker run -d \
    --name paperbanana \
    -p 8080:8080 \
    -e GOOGLE_API_KEY="your-api-key" \
    -e ENABLE_CLOUDFLARED="true" \
    -v "$(pwd)/results:/app/results" \
    paperbanana:latest
```

### Find the Public URL

The generated URL appears in the container logs:

```bash
docker logs paperbanana 2>&1 | grep "trycloudflare.com"
```

You will see output like:

```
==============================================
  Cloudflared public URL: https://random-words.trycloudflare.com
==============================================
```

### Notes

- The URL is randomly generated and changes on each container restart.
- For persistent URLs, configure a [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/) with a named tunnel and DNS record instead.
- No Cloudflare account is required for quick tunnels.

---

## Versioning

Images follow a two-part version scheme:

```
<upstream-commit-short>-<iteration>
```

| Part | Example | Meaning |
|---|---|---|
| Upstream commit | `69e6bd9` | 7-character short SHA of the PaperBanana commit the image is based on |
| Iteration | `01` | Zero-padded build iteration for Docker/config changes against the same upstream |

The current version is stored in the `VERSION` file at the repo root. When bumping:

- **New upstream commit**: Update the first part and reset iteration to `01`.
- **Docker-only changes** (Dockerfile, entrypoint, etc.): Increment the iteration number.

### Examples

```
69e6bd9-01   # First build against upstream commit 69e6bd9
69e6bd9-02   # Second iteration (e.g., entrypoint fix) same upstream
a1b2c3d-01   # New upstream commit, iteration resets
```

---

## Building Locally

### Standard Build

```bash
docker build -t paperbanana:latest .
```

### Build Against a Specific Upstream Commit

```bash
docker build \
    --build-arg UPSTREAM_COMMIT=a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2 \
    --build-arg IMAGE_VERSION=a1b2c3d-01 \
    -t paperbanana:a1b2c3d-01 .
```

### Multi-Architecture Build

```bash
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --build-arg UPSTREAM_COMMIT=69e6bd92ccc4e1c79ada7d49c0b2524a00477490 \
    --build-arg IMAGE_VERSION=69e6bd9-01 \
    -t paperbanana:69e6bd9-01 \
    --push .
```

---

## Updating the Upstream Commit

To incorporate changes from the PaperBanana repo:

```bash
# 1. Check the latest commit
git ls-remote https://github.com/dwzhu-pku/PaperBanana.git HEAD

# 2. Update the VERSION file (short hash + reset iteration)
echo "a1b2c3d-01" > VERSION

# 3. Update the UPSTREAM_COMMIT default in the Dockerfile (optional but
#    recommended for builds that don't pass --build-arg)
#    Look for the ARG UPSTREAM_COMMIT= line and update the hash.

# 4. Update docker-compose.yml build args to match

# 5. Rebuild
docker compose build --no-cache
docker compose up -d
```

---

## Troubleshooting

### Container exits immediately

Check the logs:

```bash
docker logs paperbanana
```

Common causes:
- Missing API key — set at least `GOOGLE_API_KEY` in your `.env`.
- Port conflict — change `STREAMLIT_PORT` if 8080 is in use.

### Streamlit shows "Please set your API key"

The app is running but no API key reached it. Verify:

```bash
docker exec paperbanana cat /app/configs/model_config.yaml
```

Ensure the key is not empty in the generated config.

### Cannot connect to localhost:8080

- Confirm the container is running: `docker ps`
- Confirm the port mapping: `docker port paperbanana`
- If using Docker Desktop on macOS/Windows, `localhost` should work. On Linux, verify the host firewall allows the port.

### Results disappear after container restart

Mount the results directory as a volume:

```bash
-v "$(pwd)/results:/app/results"
```

### Cloudflared tunnel not working

- Check logs: `docker logs paperbanana 2>&1 | grep cloudflared`
- Ensure `ENABLE_CLOUDFLARED=true` (not `TRUE` or `1`).
- The container requires outbound HTTPS access to Cloudflare's edge network.
