# syntax=docker/dockerfile:1

ARG PYTHON_VERSION=3.12

# =============================================================================
# Stage 1: Builder — clone upstream repo and install Python dependencies
# =============================================================================
FROM python:${PYTHON_VERSION}-slim AS builder

ARG UPSTREAM_REPO=https://github.com/dwzhu-pku/PaperBanana.git
ARG UPSTREAM_COMMIT=69e6bd92ccc4e1c79ada7d49c0b2524a00477490

RUN apt-get update && apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN git clone "${UPSTREAM_REPO}" app && \
    cd app && \
    git checkout "${UPSTREAM_COMMIT}"

# Patch: allow GEMINI_BASE_URL env var to override the Gemini API endpoint
COPY scripts/patch_generation_utils.py /tmp/patch_generation_utils.py
RUN python3 /tmp/patch_generation_utils.py && rm /tmp/patch_generation_utils.py

# Patch: guard ref.json access in planner_agent to handle missing dataset
COPY scripts/patch_planner.py /tmp/patch_planner.py
RUN python3 /tmp/patch_planner.py && rm /tmp/patch_planner.py

RUN pip install --no-cache-dir uv

RUN cd app && \
    uv venv /opt/venv && \
    . /opt/venv/bin/activate && \
    uv pip install -r requirements.txt && \
    uv pip install curl_cffi

# Download PaperBananaBench dataset for bundling into the image
RUN pip install --no-cache-dir huggingface-hub && \
    python3 - <<'PYEOF'
from huggingface_hub import snapshot_download
from pathlib import Path
import shutil
import zipfile

local_dir = Path("/opt/PaperBananaBench")
snapshot_download(
    repo_id="dwzhu/PaperBananaBench",
    repo_type="dataset",
    local_dir=str(local_dir),
    local_dir_use_symlinks=False,
)

zip_path = local_dir / "PaperBananaBench.zip"
if zip_path.exists():
    extract_dir = local_dir / "_extract_tmp"
    if extract_dir.exists():
        shutil.rmtree(extract_dir)
    extract_dir.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(zip_path) as zf:
        zf.extractall(extract_dir)

    candidates = [extract_dir, extract_dir / "PaperBananaBench"]
    extracted_root = next(
        (p for p in candidates if (p / "diagram").exists() or (p / "plot").exists()),
        None,
    )
    if extracted_root is None:
        raise RuntimeError(f"Unexpected dataset layout extracted from {zip_path}")

    for child in extracted_root.iterdir():
        shutil.move(str(child), str(local_dir / child.name))

    shutil.rmtree(extract_dir)
    zip_path.unlink()
PYEOF

# =============================================================================
# Stage 2: Runtime — lean image with app, venv, cloudflared, and entrypoint
# =============================================================================
FROM python:${PYTHON_VERSION}-slim AS runtime

ARG UPSTREAM_COMMIT=69e6bd92ccc4e1c79ada7d49c0b2524a00477490
ARG IMAGE_VERSION=69e6bd9-01
ARG TARGETARCH

LABEL org.opencontainers.image.title="PaperBanana Docker" \
      org.opencontainers.image.description="Production container for PaperBanana — automated academic illustration" \
      org.opencontainers.image.source="https://github.com/dwzhu-pku/PaperBanana" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.revision="${UPSTREAM_COMMIT}" \
      org.opencontainers.image.created="" \
      org.opencontainers.image.licenses="Apache-2.0"

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        tini \
    && rm -rf /var/lib/apt/lists/*

# Install cloudflared (opt-in at runtime via ENABLE_CLOUDFLARED=true)
RUN ARCH=$(case "${TARGETARCH}" in \
        amd64) echo "amd64" ;; \
        arm64) echo "arm64" ;; \
        *) echo "amd64" ;; \
    esac) && \
    curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}" \
        -o /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /build/app /app
COPY --from=builder /opt/PaperBananaBench /opt/PaperBananaBench

ENV PATH="/opt/venv/bin:${PATH}" \
    VIRTUAL_ENV="/opt/venv" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN mkdir -p /app/data /app/results /app/configs && \
    chmod -R 777 /app/data /app/results /app/configs && \
    chmod -R a+rX /opt/PaperBananaBench

RUN groupadd --gid 1000 appuser && \
    useradd --uid 1000 --gid appuser --shell /bin/bash --create-home appuser && \
    chown -R appuser:appuser /app

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

COPY --chown=appuser:appuser scripts/config_gateway.py /app/config_gateway.py

USER appuser

ENV GOOGLE_API_KEY="" \
    GEMINI_BASE_URL="" \
    OPENAI_API_KEY="" \
    ANTHROPIC_API_KEY="" \
    OPENROUTER_API_KEY="" \
    MAIN_MODEL_NAME="gemini-3.1-pro-preview" \
    IMAGE_GEN_MODEL_NAME="gemini-3.1-flash-image-preview" \
    ENABLE_CLOUDFLARED="false" \
    STREAMLIT_PORT="8080"

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:${STREAMLIT_PORT}/_stcore/health || exit 1

ENTRYPOINT ["tini", "--"]
CMD ["entrypoint.sh"]
