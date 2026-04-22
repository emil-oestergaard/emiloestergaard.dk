#!/usr/bin/env bash
#
# Deploy dist/ to the VPS via rsync over SSH.
#
# Required env vars (set in your shell or a gitignored .env):
#   DEPLOY_HOST   Server hostname or IP.
#   DEPLOY_USER   SSH user with write access to DEPLOY_PATH (not root).
#   DEPLOY_PATH   Absolute path on the server, e.g. /var/www/emiloestergaard.dk
#
# Optional:
#   DEPLOY_SSH_KEY  Path to the SSH private key. Defaults to ssh-agent.
#
# Usage:
#   bash deploy/deploy.sh
#
# Design notes:
#   --delete    mirrors the local dist/ onto the server. Removed files get
#               removed remotely. Safe because dist/ is fully regenerated
#               from source on every build.
#   --exclude='.well-known'  preserves ACME/Let's Encrypt HTTP challenges.
#   -a          = -rlptgoD: preserves permissions, symlinks, timestamps.

set -euo pipefail

: "${DEPLOY_HOST:?Set DEPLOY_HOST, e.g. export DEPLOY_HOST=1.2.3.4}"
: "${DEPLOY_USER:?Set DEPLOY_USER, e.g. export DEPLOY_USER=deploy}"
: "${DEPLOY_PATH:?Set DEPLOY_PATH, e.g. export DEPLOY_PATH=/var/www/emiloestergaard.dk}"

if [ ! -d dist ]; then
  echo "dist/ not found — running npm run build"
  npm run build
fi

SSH_OPTS=(-o StrictHostKeyChecking=accept-new)
if [ -n "${DEPLOY_SSH_KEY:-}" ]; then
  SSH_OPTS+=(-i "$DEPLOY_SSH_KEY")
fi

echo "→ Deploying dist/ to ${DEPLOY_USER}@${DEPLOY_HOST}:${DEPLOY_PATH}"

rsync --archive --compress --human-readable --delete \
  --exclude='.well-known' \
  -e "ssh ${SSH_OPTS[*]}" \
  dist/ "${DEPLOY_USER}@${DEPLOY_HOST}:${DEPLOY_PATH}/"

echo "✓ Done."
