# Operations Guide

## Service Management

View status:

```bash
systemctl status sing-box
systemctl status caddy
```

Restart services:

```bash
sudo systemctl restart sing-box
sudo systemctl restart caddy
```

Follow logs:

```bash
sudo journalctl -u sing-box --output cat -f
sudo journalctl -u caddy --output cat -f
```

## Client Access

Print the current Shadowsocks client parameters from the live config:

```bash
/root/vpn_server/scripts/show-client-info.sh
```

This prints:

- server address
- port
- method
- password
- `ss://` URI

## Rotate Shadowsocks Password

```bash
sudo /root/vpn_server/scripts/rotate-ss-password.sh
```

This:

- backs up the live local config
- generates a new password
- validates the config
- installs it to `/etc/sing-box/config.json`
- restarts `sing-box`

After rotation, update clients immediately.

## Monitoring UI Access

Print the live dashboard URL and login:

```bash
/root/vpn_server/scripts/show-dashboard-access.sh
```

## Monitoring UI Patch

Reapply the UI patch after a UI upgrade if the frontend starts trying to connect to `127.0.0.1:9090` again:

```bash
sudo DASHBOARD_URL="https://YOUR_HOST_OR_IP:8443" /root/vpn_server/scripts/patch-monitor-ui.sh
```

## Troubleshooting

### Browser loops back to the add-API page

Likely causes:

- stale browser local storage
- old service worker state
- frontend still using `127.0.0.1:9090`

Actions:

- open the dashboard in a private window
- clear site data for the monitoring origin
- re-run `patch-monitor-ui.sh`

### Monitoring page loads but API calls fail

Check:

- `caddy` is proxying to `127.0.0.1:9090`
- `clash_api.secret` matches the value injected by `Caddy`
- `sing-box` is still listening on `127.0.0.1:9090`

### HTTPS certificate warning

Expected when:

- you access the dashboard by raw IP
- `Caddy` uses `tls internal`

If you want a browser-trusted certificate, move the monitoring UI to a real domain and replace the self-signed/internal certificate with a normal CA-issued certificate.
