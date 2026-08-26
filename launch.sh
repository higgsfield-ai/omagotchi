#!/usr/bin/env bash
# Write a 37signals essay into Omarchy's screensaver file, then run ttfx.
set -euo pipefail

TEXT=${1-}
DEST="${HOME}/.config/omarchy/branding/screensaver.txt"
BAK="${DEST}.higgsfield-bak"

mkdir -p "$(dirname "$DEST")"
if [[ -f $DEST && ! -e $BAK ]]; then
  cp "$DEST" "$BAK"
fi
printf '%s\n' "$TEXT" > "$DEST"

if pgrep -f '[o]rg.omarchy.screensaver' >/dev/null 2>&1; then
  pkill -x ttfx 2>/dev/null || true
else
  omarchy-launch-screensaver force
fi
