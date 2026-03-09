# sing-box-ss2022-node

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
