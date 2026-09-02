#!/bin/sh
# Re-sync on every save. Needs fswatch: brew install fswatch
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [ -f "$ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env"
  set +a
fi

if ! command -v fswatch >/dev/null; then
  echo "install fswatch: brew install fswatch" >&2
  exit 1
fi

echo "watching $ROOT → ${OMARCHY_HOST:?Set OMARCHY_HOST}"
"$ROOT/dev/sync.sh"

fswatch -o \
  --exclude '/\.git/' \
  --exclude '/\.DS_Store$' \
  --exclude '/\.env$' \
  "$ROOT" | while read -r _; do
  "$ROOT/dev/sync.sh"
done
