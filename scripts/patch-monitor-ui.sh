#!/usr/bin/env bash
set -euo pipefail

UI_DIR=/var/lib/sing-box/ui
INDEX_HTML="$UI_DIR/index.html"
REGISTER_SW="$UI_DIR/registerSW.js"
SECRETS_FILE=/root/vpn_server/secrets/monitor-ui.env
BASE_URL="${1:-${DASHBOARD_URL:-}}"

if [[ -z "$BASE_URL" && -f "$SECRETS_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  . "$SECRETS_FILE"
  set +a
  BASE_URL="${DASHBOARD_URL:-}"
fi

if [[ -z "$BASE_URL" ]]; then
  echo "missing dashboard url, pass it as the first argument or set DASHBOARD_URL" >&2
  exit 1
fi

if [[ ! -f "$INDEX_HTML" ]]; then
  echo "missing UI file: $INDEX_HTML" >&2
  exit 1
fi

python3 - "$INDEX_HTML" "$REGISTER_SW" "$BASE_URL" <<'PY'
from pathlib import Path
import re
import sys

index_path = Path(sys.argv[1])
register_sw_path = Path(sys.argv[2])
base_url = sys.argv[3]

html = index_path.read_text(encoding="utf-8")
html = html.replace(
    '<link rel="manifest" href="./manifest.webmanifest"><script id="vite-plugin-pwa:register-sw" src="./registerSW.js"></script>',
    ""
)
html = re.sub(
    r'data-base-url="[^"]*"',
    f'data-base-url="{base_url}"',
    html,
    count=1,
)

bootstrap = f"""    <script>
      (() => {{
        const storageKey = "yacd.metacubex.one";
        const baseURL = "{base_url}";
        try {{
          const raw = localStorage.getItem(storageKey);
          const state = raw ? JSON.parse(raw) : {{}};
          let changed = false;
          const fallback = {{ baseURL, secret: "", addedAt: Date.now() }};
          let configs = Array.isArray(state.clashAPIConfigs) ? state.clashAPIConfigs : [];

          configs = configs
            .filter(item => item && typeof item === "object")
            .map(item => {{
              const current = typeof item.baseURL === "string" ? item.baseURL : "";
              if (/127\\.0\\.0\\.1:9090|localhost:9090/.test(current)) {{
                changed = true;
                return {{ ...item, baseURL, secret: "" }};
              }}
              return item;
            }});

          if (!configs.length) {{
            configs = [fallback];
            changed = true;
          }}

          if (!configs.some(item => item.baseURL === baseURL)) {{
            configs.unshift(fallback);
            changed = true;
          }}

          state.clashAPIConfigs = configs;
          state.selectedClashAPIConfigIndex = configs.findIndex(item => item.baseURL === baseURL);
          if (state.selectedClashAPIConfigIndex < 0) {{
            state.selectedClashAPIConfigIndex = 0;
            changed = true;
          }}

          if (changed) {{
            localStorage.setItem(storageKey, JSON.stringify(state));
          }}
        }} catch (error) {{
          console.warn("failed to normalize yacd storage", error);
        }}

        if ("serviceWorker" in navigator) {{
          navigator.serviceWorker.getRegistrations()
            .then(registrations => Promise.all(registrations.map(item => item.unregister())))
            .catch(() => {{}});
        }}

        if ("caches" in window) {{
          caches.keys()
            .then(keys => Promise.all(keys.map(key => caches.delete(key))))
            .catch(() => {{}});
        }}
      }})();
    </script>
"""

marker = "  <body>\n"
if bootstrap not in html:
    html = html.replace(marker, marker + bootstrap, 1)

html = html.replace("index-41a412db.js", "index-41a412db.js?v=20260309b")
html = html.replace("index-c34e0404.css", "index-c34e0404.css?v=20260309b")
index_path.write_text(html, encoding="utf-8")

register_sw_path.write_text("// Service worker disabled for IP-based self-signed dashboard access.\n", encoding="utf-8")
PY

echo "patched monitoring UI at $UI_DIR"
