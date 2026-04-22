# Self-hosting on a Hetzner VPS

This is a short, opinionated guide for serving the built `dist/` directory
from a Linux VPS. It's a learning path — skim, read the commentary, and
customise before running. Don't blind-copy.

## Why this way

- **Static files → a plain HTTP server.** No Node runtime, no process
  supervisor, no container. The site is HTML, CSS, and a handful of assets.
- **One machine, one service.** Either Caddy or nginx, not both.
- **HTTPS from day one** via Let's Encrypt. No exceptions.
- **Deploys are just `rsync`.** Machine state = whatever's on disk in
  `/var/www/<site>`.

## 1. Provision the server

1. Open a Hetzner Cloud project and create the smallest server. A static
   site needs almost no resources, so pick whatever's cheapest. As of
   writing, the current Hetzner lineup orders like this for the base tier
   (2 vCPU / 4 GB RAM / 40 GB SSD / 20 TB traffic):
   - **CX23** (Intel x86) — €4.49/mo. Cheapest right now.
   - **CAX11** (ARM Ampere) — €4.99/mo.
   - **CPX11** (AMD x86) — less RAM (2 GB), similar price.

   Pricing shifts with Hetzner's hardware refreshes, so double-check the
   console. Add ~€0.60/mo for the IPv4 address; Danish VAT is on top of
   that. Ubuntu 24.04 LTS is the path of least resistance for the image.
2. Add your SSH public key during creation. Don't rely on an emailed root
   password.
3. Note the public IPv4 address. Point your DNS at it:
   - `A  emiloestergaard.dk  →  <ip>`
   - `A  www.emiloestergaard.dk  →  <ip>`
   - `AAAA` records for IPv6 if your server has one.

   At Simply.com: log in → the domain → **DNS-indstillinger** → add or edit
   records. Set the TTL to something short (300s) while you're iterating;
   bump it back to default later. Verify from your laptop:

   ```bash
   dig +short emiloestergaard.dk
   dig +short www.emiloestergaard.dk
   ```

   Both should resolve to your Hetzner IP. If they don't, wait a few
   minutes — propagation isn't instant — and try again before debugging.

## 2. First SSH, and harden the box

First login is as `root` using your key. Don't stay there.

```bash
ssh root@<ip>

# Create a non-root deploy user with sudo
adduser deploy
usermod -aG sudo deploy
rsync --archive --chown=deploy:deploy ~/.ssh /home/deploy

# Log in as deploy from here on
exit
ssh deploy@<ip>
```

Tighten SSH. Edit `/etc/ssh/sshd_config` and ensure:

```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
```

Then `sudo systemctl restart ssh`.

### Firewall

UFW is the friendliest default on Ubuntu. Allow SSH first so you don't lock
yourself out:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 'WWW Full'        # 80 and 443
sudo ufw enable
sudo ufw status verbose
```

### Automatic security updates

```bash
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

### Optional but cheap

- `sudo apt install -y fail2ban` — mitigates SSH brute-force scans.
- `sudo timedatectl set-timezone Europe/Copenhagen` — set server clock.

## 3. Install a web server — pick one

### Option A: Caddy (simpler, auto-HTTPS)

Best if you want to get running quickly. Handles certificates, HTTP/2,
HTTP/3, and redirects with very little config.

```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/gpg.key | \
  sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt | \
  sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update && sudo apt install -y caddy

sudo cp deploy/Caddyfile.example /etc/caddy/Caddyfile
# Edit to match your domain + email, then:
sudo systemctl reload caddy
```

### Option B: nginx + certbot (more machinery, more learning)

You'll see more of how TLS provisioning actually works.

```bash
sudo apt install -y nginx certbot python3-certbot-nginx
sudo cp deploy/nginx/emiloestergaard.dk.conf.example \
  /etc/nginx/sites-available/emiloestergaard.dk
sudo ln -s /etc/nginx/sites-available/emiloestergaard.dk \
  /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default     # kill the default vhost
sudo nginx -t && sudo systemctl reload nginx

# Provision a certificate. Certbot edits the config in place to add
# ssl_certificate and ssl_certificate_key directives.
sudo certbot --nginx -d emiloestergaard.dk -d www.emiloestergaard.dk \
  --agree-tos -m emiloestergaard03@proton.me --non-interactive

# Certbot installs a systemd timer for renewal; confirm it:
systemctl list-timers | grep certbot
```

## 4. Prepare the web root

```bash
sudo mkdir -p /var/www/emiloestergaard.dk
sudo chown -R deploy:deploy /var/www/emiloestergaard.dk
```

## 5. First deploy from your laptop

From the project root, with your SSH key loaded:

```bash
export DEPLOY_HOST=<ip-or-hostname>
export DEPLOY_USER=deploy
export DEPLOY_PATH=/var/www/emiloestergaard.dk

npm run build
bash deploy/deploy.sh
```

Visit `https://emiloestergaard.dk`. If Caddy or nginx is serving correctly
and TLS is live, you're done. Sanity checks:

```bash
curl -I https://emiloestergaard.dk
# Expect: HTTP/2 200, a Strict-Transport-Security header, and
# Cache-Control: public, max-age=0, must-revalidate for HTML.

curl -I https://emiloestergaard.dk/_astro/<one-of-the-hashed-files>
# Expect: Cache-Control: public, max-age=31536000, immutable.

curl -I https://www.emiloestergaard.dk
# Expect: 301 redirect to https://emiloestergaard.dk/.
```

## 6. Day-two operations

Things to actually learn while running this:

- **Logs.** `journalctl -u caddy -f` or `sudo tail -f
/var/log/nginx/access.log`. Watch what real requests look like.
- **Process state.** `systemctl status caddy`. Read the unit file at
  `/lib/systemd/system/caddy.service` — it's a short, honest example of a
  systemd unit with restart policy and privilege drop.
- **Disk.** `df -h`, `du -sh /var/www/emiloestergaard.dk`. Small now;
  watch it as assets grow.
- **Networking.** `ss -tulpn` shows listening sockets; you should see 22,
  80, and 443. `sudo iptables -L` (or `sudo nft list ruleset`) shows what
  UFW actually translated your rules into.
- **Renewal.** Let's Encrypt certs expire every 90 days. Caddy renews
  silently; certbot's systemd timer does the same. Check both.
- **Reboots.** Services should come up on their own. Verify once with
  `sudo systemctl reboot` and watch.

## 7. Optional next steps

- **CI deploy.** `.github/workflows/ci.yml` currently builds and uploads
  `dist/` as an artifact. Add a `deploy` job triggered on push to `main`
  that rsyncs to the server using an SSH key stored in a GitHub secret.
  Left out intentionally — do a few manual deploys first so the moving
  parts are familiar.
- **Offsite backup of the root.** `rsync` nightly to another host, or a
  Hetzner Storage Box, or a cheap S3-compatible bucket.
- **Log shipping.** `journalctl --output=json` into Grafana Loki if you
  start caring about longitudinal logs.
- **Content Security Policy.** The reference configs emit the common hardening
  headers but no CSP — CSP wants per-site tuning. Add one once you know
  exactly which domains you load from.

## File map

- `Caddyfile.example` — primary reference if you picked Caddy.
- `nginx/emiloestergaard.dk.conf.example` — reference if you picked nginx.
- `deploy.sh` — one-shot rsync deploy. Reads `$DEPLOY_HOST`, `$DEPLOY_USER`,
  `$DEPLOY_PATH` from the environment.
