"""
Setup wizard — shown when no API keys are configured.

Writes configs/model_config.yaml so the entrypoint can detect the
change and launch the main PaperBanana application.
"""

import time
from pathlib import Path

import streamlit as st
import yaml

CONFIG_PATH = Path("/app/configs/model_config.yaml")

_PROVIDER_HELP = {
    "google": "Required when using the default Gemini models.",
    "openai": "Required when using OpenAI models (e.g. GPT-4o).",
    "anthropic": "Required when using Anthropic models (e.g. Claude).",
    "openrouter": "Unified gateway — one key for many providers.",
}


def _load_config():
    if CONFIG_PATH.exists():
        with open(CONFIG_PATH, encoding="utf-8") as f:
            return yaml.safe_load(f) or {}
    return {}


def _has_valid_keys(cfg):
    keys = cfg.get("api_keys", {})
    return any(v for v in keys.values() if v)


# ---------------------------------------------------------------------------
# Page config (must be the first Streamlit command)
# ---------------------------------------------------------------------------
st.set_page_config(page_title="PaperBanana — Setup", layout="centered")

cfg = _load_config()

# If keys are already valid the entrypoint will swap to the real app shortly.
if _has_valid_keys(cfg):
    st.title("Configuration saved")
    st.info(
        "PaperBanana is starting up — this page will refresh automatically.",
        icon="\u23f3",
    )
    time.sleep(4)
    st.rerun()

# ---------------------------------------------------------------------------
# Setup form
# ---------------------------------------------------------------------------
st.title("PaperBanana Setup")
st.markdown(
    "No API keys are configured yet. "
    "Enter at least one key below to get started."
)

existing_keys = cfg.get("api_keys", {})
existing_defaults = cfg.get("defaults", {})

with st.form("setup_form"):
    st.subheader("API Keys")
    st.caption(
        "Provide at least one key for the model provider you intend to use. "
        "The defaults assume Google Gemini."
    )

    google_key = st.text_input(
        "Google / Gemini API Key",
        value=existing_keys.get("google_api_key", ""),
        type="password",
        help=_PROVIDER_HELP["google"],
    )
    openai_key = st.text_input(
        "OpenAI API Key",
        value=existing_keys.get("openai_api_key", ""),
        type="password",
        help=_PROVIDER_HELP["openai"],
    )
    anthropic_key = st.text_input(
        "Anthropic API Key",
        value=existing_keys.get("anthropic_api_key", ""),
        type="password",
        help=_PROVIDER_HELP["anthropic"],
    )
    openrouter_key = st.text_input(
        "OpenRouter API Key",
        value=existing_keys.get("openrouter_api_key", ""),
        type="password",
        help=_PROVIDER_HELP["openrouter"],
    )

    st.divider()
    st.subheader("Model Configuration")

    col1, col2 = st.columns(2)
    with col1:
        main_model = st.text_input(
            "Main Model",
            value=existing_defaults.get(
                "main_model_name", "gemini-3.1-pro-preview"
            ),
        )
    with col2:
        image_model = st.text_input(
            "Image Generation Model",
            value=existing_defaults.get(
                "image_gen_model_name", "gemini-3.1-flash-image-preview"
            ),
        )

    submitted = st.form_submit_button(
        "Save & Launch", type="primary", use_container_width=True
    )

if submitted:
    if not any([google_key, openai_key, anthropic_key, openrouter_key]):
        st.error("Please provide at least one API key.")
    else:
        new_config = {
            "defaults": {
                "main_model_name": main_model,
                "image_gen_model_name": image_model,
            },
            "api_keys": {
                "google_api_key": google_key,
                "openai_api_key": openai_key,
                "anthropic_api_key": anthropic_key,
                "openrouter_api_key": openrouter_key,
            },
        }
        CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
        with open(CONFIG_PATH, "w", encoding="utf-8") as f:
            yaml.dump(new_config, f, default_flow_style=False)
        st.success("Configuration saved! PaperBanana is starting up...")
        time.sleep(2)
        st.rerun()
