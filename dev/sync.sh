#!/bin/sh
# Copy this repo onto the Omarchy machine. Quattro hot-reloads QML on save
# under ~/.config/omarchy/plugins/ — do not symlink; the validator rejects it.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
if [ -f "$ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env"
  set +a
fi
HOST="${OMARCHY_HOST:?Set OMARCHY_HOST (e.g. omarchy-hp or user@192.168.1.20)}"
REMOTE_DIR="${OMARCHY_PLUGIN_DIR:-.config/omarchy/plugins/higgsfield-omagotchi}"

rsync -az --delete \
  --exclude .git \
  --exclude .DS_Store \
  --exclude .env \
  --exclude '*.qmlc' \
  "$ROOT/" \
  "$HOST:$REMOTE_DIR/"

ssh "$HOST" "omarchy-shell shell rescanPlugins"

if [ "${1:-}" = "--validate" ]; then
  ssh "$HOST" "omarchy plugin validate \"\$HOME/$REMOTE_DIR\""
fi

echo "synced → $HOST:$REMOTE_DIR"
