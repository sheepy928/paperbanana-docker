#!/usr/bin/env bash
set -euo pipefail

PORT="${STREAMLIT_PORT:-8080}"

# ---------------------------------------------------------------------------
# Generate configs/model_config.yaml from environment variables if it does
# not already exist (a bind-mounted config takes precedence).
# ---------------------------------------------------------------------------
CONFIG_DIR="/app/configs"
CONFIG_FILE="${CONFIG_DIR}/model_config.yaml"

if [ ! -f "${CONFIG_FILE}" ]; then
    echo "[entrypoint] No model_config.yaml found — generating from environment variables..."
    mkdir -p "${CONFIG_DIR}"
    cat > "${CONFIG_FILE}" <<EOF
defaults:
  main_model_name: "${MAIN_MODEL_NAME:-gemini-3.1-pro-preview}"
  image_gen_model_name: "${IMAGE_GEN_MODEL_NAME:-gemini-3.1-flash-image-preview}"

api_keys:
  google_api_key: "${GOOGLE_API_KEY:-}"
  openai_api_key: "${OPENAI_API_KEY:-}"
  anthropic_api_key: "${ANTHROPIC_API_KEY:-}"
  openrouter_api_key: "${OPENROUTER_API_KEY:-}"
EOF
    echo "[entrypoint] Config written to ${CONFIG_FILE}"
else
    echo "[entrypoint] Using existing model_config.yaml"
fi

# ---------------------------------------------------------------------------
# If no API keys are configured, launch the setup wizard so the user can
# provide keys through the web UI.  The wizard writes model_config.yaml;
# once valid keys are detected the entrypoint kills the wizard and
# continues to launch the real application.
# ---------------------------------------------------------------------------
has_valid_keys() {
    python3 << 'PYEOF'
import yaml, sys
try:
    with open("/app/configs/model_config.yaml") as f:
        cfg = yaml.safe_load(f) or {}
    keys = cfg.get("api_keys", {})
    sys.exit(0 if any(v for v in keys.values() if v) else 1)
except Exception:
    sys.exit(1)
PYEOF
}

if ! has_valid_keys; then
    echo "[entrypoint] No API keys configured — launching setup wizard on port ${PORT}..."
    streamlit run /app/config_gateway.py \
        --server.port "${PORT}" \
        --server.address "0.0.0.0" \
        --server.headless true \
        --browser.gatherUsageStats false &
    SETUP_PID=$!

    while ! has_valid_keys; do
        sleep 2
    done

    echo "[entrypoint] API keys configured — stopping setup wizard..."
    kill "${SETUP_PID}" 2>/dev/null || true
    wait "${SETUP_PID}" 2>/dev/null || true
    sleep 1
fi

# ---------------------------------------------------------------------------
# Optional: start a cloudflared quick tunnel for public HTTPS access
# ---------------------------------------------------------------------------
if [ "${ENABLE_CLOUDFLARED:-false}" = "true" ]; then
    echo "[entrypoint] Starting cloudflared tunnel → http://localhost:${PORT} ..."
    cloudflared tunnel --url "http://localhost:${PORT}" --no-autoupdate 2>&1 | \
        while IFS= read -r line; do
            echo "[cloudflared] ${line}"
            # Surface the generated URL prominently
            if echo "${line}" | grep -qE 'https://.*trycloudflare\.com'; then
                URL=$(echo "${line}" | grep -oE 'https://[a-zA-Z0-9._-]+\.trycloudflare\.com')
                echo ""
                echo "=============================================="
                echo "  Cloudflared public URL: ${URL}"
                echo "=============================================="
                echo ""
            fi
        done &
    CLOUDFLARED_PID=$!
    echo "[entrypoint] cloudflared started (PID ${CLOUDFLARED_PID})"

    cleanup() {
        echo "[entrypoint] Shutting down cloudflared..."
        kill "${CLOUDFLARED_PID}" 2>/dev/null || true
        wait "${CLOUDFLARED_PID}" 2>/dev/null || true
    }
    trap cleanup EXIT INT TERM
fi

# ---------------------------------------------------------------------------
# Launch Streamlit
# ---------------------------------------------------------------------------
echo "[entrypoint] Starting Streamlit on port ${PORT}..."
exec streamlit run demo.py \
    --server.port "${PORT}" \
    --server.address "0.0.0.0" \
    --server.headless true \
    --browser.gatherUsageStats false
