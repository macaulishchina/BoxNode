# BoxNode

Single-host `Shadowsocks 2022` deployment with:

- `sing-box` for the proxy service
- `Caddy` for the HTTPS monitoring entry
- a lightweight Clash-compatible web UI exposed through reverse proxy

This repository is prepared for source control. Live secrets are intentionally excluded from git.

## Components

- Proxy service: `sing-box`
- Protocol: `Shadowsocks 2022`
- Monitoring backend: `sing-box clash_api` on `127.0.0.1:9090`
- Monitoring frontend: downloaded Yacd UI under `/var/lib/sing-box/ui`
- Public monitoring entry: `Caddy`

## Current Host Layout

This host is currently running:

- `443/tcp`: Shadowsocks 2022
- `8443/tcp`: HTTPS monitoring UI
- `9090/tcp`: loopback-only `sing-box` management API
- `22/tcp`: SSH

## Repository Layout

- `deploy/sing-box/config.example.json`: example `sing-box` server config
- `deploy/caddy/Caddyfile.example`: example `Caddy` reverse proxy config
- `secrets/monitor-ui.env.example`: example monitoring secrets file
- `scripts/install-sing-box.sh`: install `sing-box`
- `scripts/deploy-sing-box.sh`: validate and deploy `sing-box`
- `scripts/bootstrap.sh`: interactive one-click install and deploy with defaults
- `scripts/show-client-info.sh`: print current client parameters and `ss://` URI
- `scripts/rotate-ss-password.sh`: rotate the Shadowsocks password
- `scripts/patch-monitor-ui.sh`: patch the downloaded UI for public IP access
- `scripts/show-dashboard-access.sh`: print the monitoring URL and login info
- `docs/DEPLOYMENT.md`: full deployment guide
- `docs/OPERATIONS.md`: operations, rotation, troubleshooting, and web UI notes

## Live Files Not Committed

These files exist locally but are git-ignored because they contain live credentials:

- `deploy/sing-box/config.json`
- `deploy/caddy/Caddyfile`
- `secrets/monitor-ui.env`

To recreate them on another host, start from the example files in this repository.

## Quick Start

1. Run the one-click bootstrap script as root:

```bash
sudo /root/vpn_server/scripts/bootstrap.sh
```

It will:

- prompt for the required options and accept defaults when you press Enter
- install `sing-box`, `caddy`, `openssl`, and `python3`
- optionally install `qrencode`
- generate the local runtime config files under `/root/vpn_server`
- deploy `sing-box` and `caddy`
- optionally patch the dashboard UI for raw-IP HTTPS access
- print the client URI and dashboard credentials at the end

2. For unattended deployment, pass `-y` or preseed environment variables:

```bash
sudo SS_PORT=443 DASHBOARD_HOST=1.2.3.4 DASHBOARD_PORT=8443 \
  DASHBOARD_USER=admin DASHBOARD_PASS='strong-password' \
  SS_PASSWORD='another-strong-password' CLASH_API_SECRET='hex-secret' \
  /root/vpn_server/scripts/bootstrap.sh -y
```

3. If you prefer the old manual flow, see [DEPLOYMENT.md](/root/vpn_server/docs/DEPLOYMENT.md).

## Manual Flow

1. Copy the example files:

```bash
cp /root/vpn_server/deploy/sing-box/config.example.json /root/vpn_server/deploy/sing-box/config.json
cp /root/vpn_server/deploy/caddy/Caddyfile.example /root/vpn_server/deploy/caddy/Caddyfile
cp /root/vpn_server/secrets/monitor-ui.env.example /root/vpn_server/secrets/monitor-ui.env
chmod 700 /root/vpn_server/secrets
chmod 600 /root/vpn_server/secrets/monitor-ui.env
```

2. Fill in the real values:

- `deploy/sing-box/config.json`
- `deploy/caddy/Caddyfile`
- `secrets/monitor-ui.env`

3. Install and deploy:

```bash
sudo /root/vpn_server/scripts/install-sing-box.sh
sudo /root/vpn_server/scripts/deploy-sing-box.sh
sudo install -m 644 /root/vpn_server/deploy/caddy/Caddyfile /etc/caddy/Caddyfile
sudo systemctl restart caddy
```

4. Patch the downloaded UI if you expose it publicly by IP:

```bash
sudo DASHBOARD_URL="https://YOUR_HOST:PORT" /root/vpn_server/scripts/patch-monitor-ui.sh
```

## Documentation

- [DEPLOYMENT.md](/root/vpn_server/docs/DEPLOYMENT.md)
- [OPERATIONS.md](/root/vpn_server/docs/OPERATIONS.md)
