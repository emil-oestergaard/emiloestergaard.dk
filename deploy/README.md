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
   site needs almost no resources, so pick whatever's cheapest. At the
   time of writing, the entry tier is:
   - **CX23** (Cost-Optimized, x86, 2 vCPU / 4 GB RAM / 80 GB SSD / 20 TB)
     — €3.99/mo. This is the right pick.

   Hetzner groups cloud servers into three categories in the UI:
   - **Cost-Optimized** — CX (Intel/AMD) and CAX (ARM). Cheapest.
   - **Regular Performance** — CPX (AMD EPYC). Faster per-core, ~2×
     the price. Unnecessary for serving static files.
   - **Dedicated / General Purpose** — CCX. Pinned cores, no noisy
     neighbours, ~3× the price. Pure overkill here.

   Add ~€0.60/mo for the IPv4 address; Danish VAT is on top. Ubuntu 24.04
   LTS is the path of least resistance for the image.

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
sudo ufw allow 80/tcp            # HTTP (Let's Encrypt + redirects)
sudo ufw allow 443/tcp           # HTTPS
sudo ufw enable
sudo ufw status verbose
```

Note: `'WWW Full'` is an alias some Ubuntu builds ship and some don't — explicit
port numbers are portable and self-documenting.

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

# Get the Caddyfile onto the server (same choice as the nginx section):
#   Option 1 — pull from GitHub:
sudo curl -fsSL \
  https://raw.githubusercontent.com/emil-oestergaard/emiloestergaard.dk/main/deploy/Caddyfile.example \
  -o /etc/caddy/Caddyfile
#   Option 2 — scp from your laptop:
#     scp deploy/Caddyfile.example deploy@<ip>:/tmp/Caddyfile
#     sudo mv /tmp/Caddyfile /etc/caddy/Caddyfile
#     sudo chown root:root /etc/caddy/Caddyfile

sudo systemctl reload caddy
```

### Option B: nginx + certbot (more machinery, more learning)

You'll see more of how TLS provisioning actually works.

```bash
sudo apt install -y nginx certbot python3-certbot-nginx
```

Next you need to get `deploy/nginx/emiloestergaard.dk.conf.example` onto
the server. The `deploy/` directory lives in your local repo, not on the
server, so pick one of:

```bash
# Option 1 — from the server, pull straight from your public GitHub repo:
sudo curl -fsSL \
  https://raw.githubusercontent.com/emil-oestergaard/emiloestergaard.dk/main/deploy/nginx/emiloestergaard.dk.conf.example \
  -o /etc/nginx/sites-available/emiloestergaard.dk

# Option 2 — from your laptop, scp it in (works whether the repo is public or private):
#   scp deploy/nginx/emiloestergaard.dk.conf.example deploy@<ip>:/tmp/nginx.conf
# Then on the server:
#   sudo mv /tmp/nginx.conf /etc/nginx/sites-available/emiloestergaard.dk
#   sudo chown root:root /etc/nginx/sites-available/emiloestergaard.dk
```

Enable the site and remove the default vhost:

```bash
sudo ln -s /etc/nginx/sites-available/emiloestergaard.dk \
  /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
```

At this point `nginx -t` will fail — the HTTPS `server` blocks declare TLS
but the certificates don't exist yet. Expected. Get the cert with certbot
in standalone mode (certbot runs its own temporary HTTP server on port 80,
no working nginx required):

```bash
sudo systemctl stop nginx    # free port 80 for certbot
sudo certbot certonly --standalone -d emiloestergaard.dk -d www.emiloestergaard.dk --agree-tos -m emiloestergaard03@proton.me --non-interactive
```

Certs now live under `/etc/letsencrypt/live/emiloestergaard.dk/`. Add the
two paths to our config — one pair per HTTPS server block, inserted after
the `# certbot injects ssl_certificate lines here` marker:

```bash
sudo sed -i '/certbot injects ssl_certificate lines here/a\    ssl_certificate_key /etc/letsencrypt/live/emiloestergaard.dk/privkey.pem;' /etc/nginx/sites-available/emiloestergaard.dk
sudo sed -i '/certbot injects ssl_certificate lines here/a\    ssl_certificate /etc/letsencrypt/live/emiloestergaard.dk/fullchain.pem;' /etc/nginx/sites-available/emiloestergaard.dk
```

Test and start:

```bash
sudo nginx -t && sudo systemctl start nginx
```

Confirm the renewal timer is armed (installed by the certbot apt package):

```bash
systemctl list-timers | grep certbot
```

**Renewal caveat.** Because the initial cert was issued via `--standalone`,
the renewal config will try the same method — which requires port 80, but
nginx will be holding it. Before the first renewal (~60 days out), edit
`/etc/letsencrypt/renewal/emiloestergaard.dk.conf` and either add
`pre_hook = systemctl stop nginx` + `post_hook = systemctl start nginx`,
or switch the authenticator to `webroot` pointing at `/var/www/certbot`.
Test with `sudo certbot renew --dry-run`.

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
