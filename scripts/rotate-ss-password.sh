#!/usr/bin/env bash
set -euo pipefail

WORKDIR=/root/vpn_server
WORK_CFG="$WORKDIR/deploy/sing-box/config.json"
SYS_CFG=/etc/sing-box/config.json
BACKUP_DIR="$WORKDIR/backups"

if ! command -v sing-box >/dev/null 2>&1; then
  echo "sing-box is not installed" >&2
  exit 1
fi

if [[ ! -f "$WORK_CFG" ]]; then
  echo "missing config: $WORK_CFG" >&2
  exit 1
fi

install -d -m 700 "$BACKUP_DIR"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"

cp "$WORK_CFG" "$BACKUP_DIR/config.json.$timestamp.bak"

new_password="$(sing-box generate rand --base64 16)"

python3 - "$WORK_CFG" "$new_password" <<'PY'
import json
import sys

config_path, new_password = sys.argv[1:3]

with open(config_path, "r", encoding="utf-8") as fh:
    config = json.load(fh)

for item in config.get("inbounds", []):
    if item.get("type") == "shadowsocks":
        item["password"] = new_password
        break
else:
    raise SystemExit("no shadowsocks inbound found in config")

with open(config_path, "w", encoding="utf-8") as fh:
    json.dump(config, fh, indent=2)
    fh.write("\n")
PY

sing-box check -c "$WORK_CFG"
install -m 600 "$WORK_CFG" "$SYS_CFG"
systemctl restart sing-box

echo "password rotated"
echo "backup: $BACKUP_DIR/config.json.$timestamp.bak"
echo "new client parameters:"
"$WORKDIR/scripts/show-client-info.sh" "$WORK_CFG"
