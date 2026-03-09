#!/usr/bin/env bash
set -euo pipefail

WORKDIR=/root/vpn_server
SING_TEMPLATE="$WORKDIR/deploy/sing-box/config.example.json"
CADDY_TEMPLATE="$WORKDIR/deploy/caddy/Caddyfile.example"
SECRETS_DIR="$WORKDIR/secrets"
SECRETS_FILE="$SECRETS_DIR/monitor-ui.env"
SING_WORK_CONFIG="$WORKDIR/deploy/sing-box/config.json"
CADDY_WORK_CONFIG="$WORKDIR/deploy/caddy/Caddyfile"
BACKUP_DIR="$WORKDIR/backups/bootstrap"

AUTO_YES=0

for arg in "$@"; do
  case "$arg" in
    -y|--yes|--non-interactive)
      AUTO_YES=1
      ;;
    *)
      echo "unknown argument: $arg" >&2
      echo "usage: $0 [-y|--yes|--non-interactive]" >&2
      exit 1
      ;;
  esac
done

if [[ "${EUID}" -ne 0 ]]; then
  echo "run as root: sudo $0" >&2
  exit 1
fi

detect_ipv4() {
  ip -o -4 addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -n1
}

random_base64() {
  local length="${1:-16}"
  if command -v sing-box >/dev/null 2>&1; then
    sing-box generate rand --base64 "$length"
  else
    openssl rand -base64 "$length" | tr -d '\n'
  fi
}

random_hex() {
  local length="${1:-16}"
  openssl rand -hex "$length" | tr -d '\n'
}

default_if_empty() {
  local value="$1"
  local fallback="$2"

  if [[ -n "$value" ]]; then
    printf '%s' "$value"
  else
    printf '%s' "$fallback"
  fi
}

prompt_value() {
  local var_name="$1"
  local prompt_text="$2"
  local default_value="$3"
  local current_value="${!var_name:-}"

  current_value="$(default_if_empty "$current_value" "$default_value")"

  if [[ "$AUTO_YES" -eq 1 || ! -t 0 ]]; then
    printf -v "$var_name" '%s' "$current_value"
    return
  fi

  read -r -p "$prompt_text [$current_value]: " reply
  if [[ -n "$reply" ]]; then
    current_value="$reply"
  fi

  printf -v "$var_name" '%s' "$current_value"
}

prompt_yes_no() {
  local var_name="$1"
  local prompt_text="$2"
  local default_value="$3"
  local current_value="${!var_name:-}"

  current_value="$(default_if_empty "$current_value" "$default_value")"
  current_value="$(printf '%s' "$current_value" | tr '[:upper:]' '[:lower:]')"

  if [[ "$AUTO_YES" -eq 1 || ! -t 0 ]]; then
    printf -v "$var_name" '%s' "$current_value"
    return
  fi

  while true; do
    read -r -p "$prompt_text [$current_value]: " reply
    reply="$(default_if_empty "$reply" "$current_value")"
    reply="$(printf '%s' "$reply" | tr '[:upper:]' '[:lower:]')"
    case "$reply" in
      y|yes|n|no)
        printf -v "$var_name" '%s' "$reply"
        return
        ;;
    esac
    echo "enter yes or no" >&2
  done
}

normalize_yes_no() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    y|yes) printf 'yes' ;;
    n|no) printf 'no' ;;
    *) return 1 ;;
  esac
}

backup_if_exists() {
  local path="$1"
  local target_dir="$2"

  if [[ -f "$path" ]]; then
    install -d -m 700 "$target_dir"
    cp "$path" "$target_dir/"
  fi
}

wait_for_ui() {
  local timeout="${1:-30}"
  local deadline=$((SECONDS + timeout))

  while (( SECONDS < deadline )); do
    if [[ -f /var/lib/sing-box/ui/index.html ]]; then
      return 0
    fi
    sleep 1
  done

  return 1
}

PRIMARY_IP="$(detect_ipv4 || true)"
PRIMARY_IP="$(default_if_empty "$PRIMARY_IP" "127.0.0.1")"

SS_PORT="${SS_PORT:-}"
DASHBOARD_HOST="${DASHBOARD_HOST:-}"
DASHBOARD_PORT="${DASHBOARD_PORT:-}"
DASHBOARD_USER="${DASHBOARD_USER:-}"
DASHBOARD_PASS="${DASHBOARD_PASS:-}"
SS_PASSWORD="${SS_PASSWORD:-}"
CLASH_API_SECRET="${CLASH_API_SECRET:-}"
INSTALL_QRENCODE="${INSTALL_QRENCODE:-}"
CONFIGURE_UFW="${CONFIGURE_UFW:-}"
PATCH_UI="${PATCH_UI:-}"

prompt_value SS_PORT "Shadowsocks listen port" "443"
prompt_value DASHBOARD_HOST "Dashboard host or IP" "$PRIMARY_IP"
prompt_value DASHBOARD_PORT "Dashboard HTTPS port" "8443"
prompt_value DASHBOARD_USER "Dashboard username" "admin"
prompt_value DASHBOARD_PASS "Dashboard password" "$(random_base64 12)"
prompt_value SS_PASSWORD "Shadowsocks password" "$(random_base64 16)"
prompt_value CLASH_API_SECRET "Clash API secret" "$(random_hex 16)"
prompt_yes_no INSTALL_QRENCODE "Install qrencode for QR output?" "yes"
prompt_yes_no CONFIGURE_UFW "Apply UFW allow rules for SSH, Shadowsocks, dashboard?" "no"

if [[ "$DASHBOARD_HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  PATCH_UI_DEFAULT="yes"
else
  PATCH_UI_DEFAULT="no"
fi
prompt_yes_no PATCH_UI "Patch dashboard UI for IP/self-signed access?" "$PATCH_UI_DEFAULT"

INSTALL_QRENCODE="$(normalize_yes_no "$INSTALL_QRENCODE")"
CONFIGURE_UFW="$(normalize_yes_no "$CONFIGURE_UFW")"
PATCH_UI="$(normalize_yes_no "$PATCH_UI")"

if [[ ! "$SS_PORT" =~ ^[0-9]+$ ]] || (( SS_PORT < 1 || SS_PORT > 65535 )); then
  echo "invalid Shadowsocks port: $SS_PORT" >&2
  exit 1
fi

if [[ ! "$DASHBOARD_PORT" =~ ^[0-9]+$ ]] || (( DASHBOARD_PORT < 1 || DASHBOARD_PORT > 65535 )); then
  echo "invalid dashboard port: $DASHBOARD_PORT" >&2
  exit 1
fi

if [[ -z "$DASHBOARD_HOST" || -z "$DASHBOARD_USER" || -z "$DASHBOARD_PASS" || -z "$SS_PASSWORD" || -z "$CLASH_API_SECRET" ]]; then
  echo "required values cannot be empty" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ca-certificates curl gnupg openssl caddy python3
if [[ "$INSTALL_QRENCODE" == "yes" ]]; then
  apt-get install -y qrencode
fi

"$WORKDIR/scripts/install-sing-box.sh"

if [[ ! -f "$SING_TEMPLATE" || ! -f "$CADDY_TEMPLATE" ]]; then
  echo "missing template files" >&2
  exit 1
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_root="$BACKUP_DIR/$timestamp"
backup_if_exists "$SING_WORK_CONFIG" "$backup_root"
backup_if_exists "$CADDY_WORK_CONFIG" "$backup_root"
backup_if_exists "$SECRETS_FILE" "$backup_root"

install -d -m 755 "$(dirname "$SING_WORK_CONFIG")" "$(dirname "$CADDY_WORK_CONFIG")"
install -d -m 700 "$SECRETS_DIR"

DASHBOARD_SITE="${DASHBOARD_HOST}:${DASHBOARD_PORT}"
DASHBOARD_URL="https://${DASHBOARD_HOST}:${DASHBOARD_PORT}/ui/"
BCRYPT_HASH="$(caddy hash-password --plaintext "$DASHBOARD_PASS")"

python3 - "$SING_TEMPLATE" "$SING_WORK_CONFIG" "$SS_PORT" "$SS_PASSWORD" "$CLASH_API_SECRET" <<'PY'
from pathlib import Path
import json
import sys

template_path, output_path, port, password, secret = sys.argv[1:6]

config = json.loads(Path(template_path).read_text(encoding="utf-8"))

for inbound in config.get("inbounds", []):
    if inbound.get("type") == "shadowsocks":
        inbound["listen_port"] = int(port)
        inbound["password"] = password
        break
else:
    raise SystemExit("no shadowsocks inbound found in template")

clash_api = config.setdefault("experimental", {}).setdefault("clash_api", {})
clash_api["secret"] = secret

Path(output_path).write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
PY

python3 - "$CADDY_TEMPLATE" "$CADDY_WORK_CONFIG" "$DASHBOARD_SITE" "$DASHBOARD_USER" "$BCRYPT_HASH" "$CLASH_API_SECRET" <<'PY'
from pathlib import Path
import sys

template_path, output_path, site, user, bcrypt_hash, secret = sys.argv[1:7]

content = Path(template_path).read_text(encoding="utf-8")
content = content.replace("YOUR_HOST_OR_IP:8443", site)
content = content.replace("YOUR_DASHBOARD_USER", user)
content = content.replace("YOUR_BCRYPT_HASH", bcrypt_hash)
content = content.replace("YOUR_CLASH_API_SECRET", secret)

Path(output_path).write_text(content, encoding="utf-8")
PY

cat >"$SECRETS_FILE" <<EOF
DASHBOARD_URL=${DASHBOARD_URL}
DASHBOARD_USER=${DASHBOARD_USER}
DASHBOARD_PASS=${DASHBOARD_PASS}
CLASH_API_SECRET=${CLASH_API_SECRET}
EOF
chmod 600 "$SECRETS_FILE"

"$WORKDIR/scripts/deploy-sing-box.sh"

install -m 644 "$CADDY_WORK_CONFIG" /etc/caddy/Caddyfile
caddy validate --config /etc/caddy/Caddyfile
systemctl enable caddy
systemctl restart caddy

if [[ "$PATCH_UI" == "yes" ]]; then
  if wait_for_ui 30; then
    DASHBOARD_URL="$DASHBOARD_URL" "$WORKDIR/scripts/patch-monitor-ui.sh"
  else
    echo "warning: UI assets were not ready within 30s, skipping patch" >&2
  fi
fi

if [[ "$CONFIGURE_UFW" == "yes" ]] && command -v ufw >/dev/null 2>&1; then
  ufw allow 22/tcp
  ufw allow "${SS_PORT}/tcp"
  ufw allow "${DASHBOARD_PORT}/tcp"
fi

echo
echo "Deployment complete."
echo
"$WORKDIR/scripts/show-client-info.sh" "$SING_WORK_CONFIG"
echo
"$WORKDIR/scripts/show-dashboard-access.sh"
