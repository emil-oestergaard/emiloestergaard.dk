#!/usr/bin/env bash
#
# Manual deploy: build locally, rsync into releases/<id>/ on the VPS,
# then SSH in and flip the `current` symlink.
#
# CI uses the same two-step flow in .github/workflows/ci.yml.
#
# Required env vars (set in your shell or a gitignored .env):
#   DEPLOY_HOST   Server hostname or IP.
#   DEPLOY_USER   SSH user (non-root) with write access to DEPLOY_PATH.
#   DEPLOY_PATH   Absolute path on the server, e.g. /var/www/emiloestergaard.dk
#
# Optional:
#   DEPLOY_SSH_KEY  Path to the SSH private key. Defaults to ssh-agent.
#
# One-time server setup is required — see deploy/README.md § "Release layout".

set -euo pipefail

: "${DEPLOY_HOST:?Set DEPLOY_HOST, e.g. export DEPLOY_HOST=1.2.3.4}"
: "${DEPLOY_USER:?Set DEPLOY_USER, e.g. export DEPLOY_USER=deploy}"
: "${DEPLOY_PATH:?Set DEPLOY_PATH, e.g. export DEPLOY_PATH=/var/www/emiloestergaard.dk}"

if [ ! -d dist ]; then
  echo "dist/ not found — running npm run build"
  npm run build
fi

if release_id="$(git rev-parse HEAD 2>/dev/null)"; then
  :
else
  release_id="manual-$(date -u +%Y%m%dT%H%M%SZ)"
fi

SSH_OPTS=(-o StrictHostKeyChecking=accept-new)
if [ -n "${DEPLOY_SSH_KEY:-}" ]; then
  SSH_OPTS+=(-i "$DEPLOY_SSH_KEY")
fi

target="${DEPLOY_USER}@${DEPLOY_HOST}:${DEPLOY_PATH}/releases/${release_id}/"

echo "→ Uploading dist/ to ${target}"
rsync --archive --compress --human-readable --delete \
  -e "ssh ${SSH_OPTS[*]}" \
  dist/ "$target"

echo "→ Activating release ${release_id}"
ssh "${SSH_OPTS[@]}" "${DEPLOY_USER}@${DEPLOY_HOST}" \
  "${DEPLOY_PATH}/bin/release-swap.sh ${release_id}"

echo "✓ Deployed ${release_id}"
