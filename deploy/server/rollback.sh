#!/usr/bin/env bash
#
# Installed at: /var/www/<site>/bin/rollback.sh
#
# List releases, or flip `current` back to an earlier one.
#
# Usage:
#   rollback.sh                # list releases, mark the live one
#   rollback.sh --previous     # flip to the newest release that isn't live
#   rollback.sh <release-id>   # flip to a named release

set -euo pipefail

BASE="$(cd "$(dirname "$0")/.." && pwd)"
RELEASES_DIR="$BASE/releases"

current_target=""
if [ -L "$BASE/current" ]; then
  current_target="$(basename "$(readlink "$BASE/current")")"
fi

mapfile -t releases < <(
  find "$RELEASES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' \
    | sort -rn \
    | awk '{print $2}'
)

if [ $# -eq 0 ]; then
  echo "Releases (newest first):"
  for r in "${releases[@]}"; do
    if [ "$r" = "$current_target" ]; then
      echo "  * $r   (current)"
    else
      echo "    $r"
    fi
  done
  echo
  echo "Roll back with: $(basename "$0") <release-id>"
  echo "Or flip to the most recent non-live release: $(basename "$0") --previous"
  exit 0
fi

target="$1"
if [ "$target" = "--previous" ]; then
  target=""
  for r in "${releases[@]}"; do
    if [ "$r" != "$current_target" ]; then
      target="$r"
      break
    fi
  done
  if [ -z "$target" ]; then
    echo "rollback: no previous release available" >&2
    exit 1
  fi
fi

if [ ! -d "$RELEASES_DIR/$target" ]; then
  echo "rollback: releases/$target does not exist" >&2
  exit 1
fi

exec "$(dirname "$0")/release-swap.sh" "$target"
