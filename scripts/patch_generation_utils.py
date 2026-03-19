#!/usr/bin/env python3
"""Patch generation_utils.py to support GEMINI_BASE_URL."""
import re
import sys
from pathlib import Path

path = Path("app/utils/generation_utils.py")
src = path.read_text()

pattern = (
    r'(?P<indent>[ \t]*)gemini_client = genai\.Client\(api_key=api_key\)\n'
    r'(?P=indent)print\("Initialized Gemini Client with API Key"\)'
)

m = re.search(pattern, src)
if not m:
    print(
        "ERROR: patch target not found in generation_utils.py — upstream may have changed",
        file=sys.stderr,
    )
    sys.exit(1)

ind = m.group("indent")
replacement = "\n".join(
    [
        ind + '_gemini_base = os.getenv("GEMINI_BASE_URL", "")',
        ind
        + 'gemini_client = genai.Client(api_key=api_key, http_options={"base_url": _gemini_base}) if _gemini_base else genai.Client(api_key=api_key)',
        ind + 'print(f"Initialized Gemini Client with API Key{\' via custom base URL\' if _gemini_base else \'\'}")',
    ]
)

src = src[: m.start()] + replacement + src[m.end() :]
path.write_text(src)

print("Patched generation_utils.py: added GEMINI_BASE_URL support")
