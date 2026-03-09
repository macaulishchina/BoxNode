#!/usr/bin/env bash
set -euo pipefail

WORKDIR=/root/vpn_server
CONFIG_SRC="$WORKDIR/deploy/sing-box/config.json"
CONFIG_DST=/etc/sing-box/config.json

if [[ ! -f "$CONFIG_SRC" ]]; then
  echo "missing config: $CONFIG_SRC" >&2
  exit 1
fi

install -d -m 755 /etc/sing-box

if command -v sing-box >/dev/null 2>&1; then
  sing-box check -c "$CONFIG_SRC"
else
  echo "sing-box is not installed" >&2
  exit 1
fi

install -m 600 "$CONFIG_SRC" "$CONFIG_DST"
systemctl enable sing-box
systemctl restart sing-box
systemctl --no-pager --full status sing-box
