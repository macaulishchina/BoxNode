#!/usr/bin/env bash
set -euo pipefail

CONFIG_PATH="${1:-/etc/sing-box/config.json}"
SERVER_ADDRESS="${SERVER_ADDRESS:-}"
TAG="${TAG:-vpn_server ss2022}"

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "missing config: $CONFIG_PATH" >&2
  exit 1
fi

if [[ -z "$SERVER_ADDRESS" ]]; then
  SERVER_ADDRESS="$(ip -o -4 addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -n1)"
fi

if [[ -z "$SERVER_ADDRESS" ]]; then
  echo "could not determine server address, set SERVER_ADDRESS=..." >&2
  exit 1
fi

python3 - "$CONFIG_PATH" "$SERVER_ADDRESS" "$TAG" <<'PY'
import json
import sys
from urllib.parse import quote

config_path, server_address, tag = sys.argv[1:4]

with open(config_path, "r", encoding="utf-8") as fh:
    config = json.load(fh)

inbound = None
for item in config.get("inbounds", []):
    if item.get("type") == "shadowsocks":
        inbound = item
        break

if inbound is None:
    raise SystemExit("no shadowsocks inbound found in config")

method = inbound["method"]
password = inbound["password"]
port = inbound["listen_port"]
network = inbound.get("network", "tcp,udp")

userinfo = f"{quote(method, safe='')}:{quote(password, safe='')}"
uri = f"ss://{userinfo}@{server_address}:{port}#{quote(tag, safe='')}"

print(f"Server:    {server_address}")
print(f"Port:      {port}")
print(f"Method:    {method}")
print(f"Password:  {password}")
print(f"Transport: {network}")
print()
print("SIP002 URI:")
print(uri)
print()
print("Minimal sing-box outbound example:")
print(json.dumps({
    "type": "shadowsocks",
    "server": server_address,
    "server_port": port,
    "method": method,
    "password": password
}, indent=2))
PY

if [[ "${NO_QR:-0}" != "1" ]] && command -v qrencode >/dev/null 2>&1; then
  echo
  echo "QR code:"
  NO_QR=1 /root/vpn_server/scripts/show-client-info.sh "$CONFIG_PATH" | awk '/^ss:\/\// { print }' | qrencode -t ANSIUTF8
fi
