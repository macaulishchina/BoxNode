# Deployment Guide

This guide documents the current layout used on the host and how to reproduce it safely on another Ubuntu/Debian server.

## Architecture

- `sing-box` listens for `Shadowsocks 2022` client traffic.
- `sing-box clash_api` listens only on `127.0.0.1:9090`.
- `Caddy` publishes the monitoring UI over HTTPS and injects the backend bearer secret.
- The downloaded UI lives at `/var/lib/sing-box/ui`.

## Packages

Required packages:

- `sing-box`
- `caddy`
- `openssl`
- optional: `qrencode`

## Recommended Host Baseline

- OS: `Ubuntu 24.04 LTS` or `Debian 12`
- Public firewall: default deny inbound
- SSH: key-only login
- Service separation: do not mix this with unrelated public workloads if you can avoid it

## Files

Live runtime paths:

- `/etc/sing-box/config.json`
- `/etc/caddy/Caddyfile`
- `/var/lib/sing-box/ui`
- `/root/vpn_server/secrets/monitor-ui.env`

Repository templates:

- `deploy/sing-box/config.example.json`
- `deploy/caddy/Caddyfile.example`
- `secrets/monitor-ui.env.example`

## Install sing-box

```bash
sudo /root/vpn_server/scripts/install-sing-box.sh
```

## Prepare sing-box Config

Create the live config from the example:

```bash
cp /root/vpn_server/deploy/sing-box/config.example.json /root/vpn_server/deploy/sing-box/config.json
```

Set at least:

- `listen_port`
- `password`
- `experimental.clash_api.secret`

Then deploy:

```bash
sudo /root/vpn_server/scripts/deploy-sing-box.sh
```

## Prepare Caddy

Create the live config from the example:

```bash
cp /root/vpn_server/deploy/caddy/Caddyfile.example /root/vpn_server/deploy/caddy/Caddyfile
```

Set at least:

- site address, such as `YOUR_HOST_OR_IP:8443`
- dashboard username
- bcrypt password hash
- `Bearer` secret that matches `clash_api.secret`

Install to systemd path:

```bash
sudo install -m 644 /root/vpn_server/deploy/caddy/Caddyfile /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl restart caddy
```

## Monitoring Secrets File

Create the live secrets file:

```bash
mkdir -p /root/vpn_server/secrets
cp /root/vpn_server/secrets/monitor-ui.env.example /root/vpn_server/secrets/monitor-ui.env
chmod 700 /root/vpn_server/secrets
chmod 600 /root/vpn_server/secrets/monitor-ui.env
```

Fill in:

- `DASHBOARD_URL`
- `DASHBOARD_USER`
- `DASHBOARD_PASS`
- `CLASH_API_SECRET`

## Firewall

Current host policy:

- `22/tcp` for SSH
- `443/tcp` for Shadowsocks
- `8443/tcp` for HTTPS monitoring

Example:

```bash
sudo ufw allow 22/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8443/tcp
```

## UI Patch for IP-Based Access

If the monitoring UI is published by raw IP and a self-signed certificate, patch the downloaded UI:

```bash
sudo DASHBOARD_URL="https://YOUR_HOST_OR_IP:8443" /root/vpn_server/scripts/patch-monitor-ui.sh
```

This does two things:

- disables the service worker
- rewrites cached/default backend settings away from `127.0.0.1:9090`

## Verification

Check services:

```bash
systemctl is-enabled sing-box
systemctl is-active sing-box
systemctl is-enabled caddy
systemctl is-active caddy
```

Check listening ports:

```bash
ss -lnt '( sport = :443 or sport = :8443 or sport = :9090 )'
```
