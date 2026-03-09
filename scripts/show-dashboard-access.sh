#!/usr/bin/env bash
set -euo pipefail

SECRETS_FILE=/root/vpn_server/secrets/monitor-ui.env

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "missing secrets file: $SECRETS_FILE" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$SECRETS_FILE"
set +a

cat <<EOF
Public URL:   ${DASHBOARD_URL}
Username:     ${DASHBOARD_USER}
Password:     ${DASHBOARD_PASS}

Notes:
- The site uses an internal TLS certificate, so browsers will warn until you trust the CA or ignore the warning.
- The backend API itself stays on 127.0.0.1:9090 and is not directly public.
EOF
