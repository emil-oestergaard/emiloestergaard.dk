#!/usr/bin/env bash
#
# Installed at: /var/www/<site>/bin/release-swap.sh
#
# Flip the `current` symlink to a release, then prune old releases.
# Called over SSH by CI and by deploy/deploy.sh immediately after an
# rsync to releases/<id>/.
#
# Usage: release-swap.sh <release-id>
#
# Layout (BASE = parent of this script's directory):
#   $BASE/releases/<id>/   — full site contents
#   $BASE/current          — symlink pointing at releases/<id>
#
# The swap uses rename(2) so readers never observe a half-updated link.

set -euo pipefail

BASE="$(cd "$(dirname "$0")/.." && pwd)"
RELEASES_DIR="$BASE/releases"
KEEP=5

release_id="${1:?Usage: release-swap.sh <release-id>}"
release_path="$RELEASES_DIR/$release_id"

if [ ! -d "$release_path" ]; then
  echo "release-swap: $release_path does not exist" >&2
  exit 1
fi

# Minimum viable sanity check. Astro always emits index.html; its absence
# means the upload was truncated or targeted the wrong directory.
if [ ! -f "$release_path/index.html" ]; then
  echo "release-swap: $release_path/index.html missing; refusing to swap" >&2
  exit 1
fi

# Serialize concurrent swaps from parallel CI runs or a manual deploy
# racing CI. Second caller waits instead of interleaving.
lockfile="$BASE/.release-swap.lock"
exec 9>"$lockfile"
flock 9

# Two-step atomic swap: create a fresh symlink under a temp name, then
# rename it over `current`. Works on every POSIX filesystem Let's
# Encrypt, Caddy, and nginx run on.
ln -sfn "releases/$release_id" "$BASE/current.tmp"
mv -Tf "$BASE/current.tmp" "$BASE/current"

echo "release-swap: current -> releases/$release_id"

# Prune. Keep the KEEP newest by mtime; always retain whatever `current`
# points at, even if it's older (post-rollback case).
current_target="$(basename "$(readlink "$BASE/current")")"

mapfile -t sorted < <(
  find "$RELEASES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' \
    | sort -rn \
    | awk '{print $2}'
)

keep=("${sorted[@]:0:$KEEP}")
protected=0
for k in "${keep[@]}"; do
  [ "$k" = "$current_target" ] && protected=1
done
[ "$protected" = 0 ] && keep+=("$current_target")

for name in "${sorted[@]}"; do
  drop=1
  for k in "${keep[@]}"; do
    [ "$k" = "$name" ] && drop=0
  done
  if [ "$drop" = 1 ]; then
    echo "release-swap: pruning releases/$name"
    rm -rf "${RELEASES_DIR:?}/$name"
  fi
done
