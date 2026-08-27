#!/usr/bin/env bash
# Play a prebuilt Higgsfield clip via mpv. Blocks until mpv exits.
# commit/fail: centered floating overlay, one play, then the window is gone.
# screensaver: fullscreen, one play.
set -euo pipefail

KIND=${1-}
FILE=${2-}
MONITOR=${3-}

if [[ -z $KIND || -z $FILE || ! -f $FILE ]]; then
  echo "usage: play.sh <commit|fail|screensaver> <file> [monitor]" >&2
  exit 1
fi

pkill -f '[m]pv --title=higgsfield-signals-clip' 2>/dev/null || true
sleep 0.05

quoted=$(printf '%q' "$FILE")
mpv="mpv --title=higgsfield-signals-clip --no-terminal --really-quiet --ontop --no-border --osc=no --osd-level=0 --keep-open=no --loop=no --keepaspect=yes --no-input-default-bindings --cursor-autohide=always -- ${quoted}"

if ! command -v hyprctl >/dev/null 2>&1; then
  eval exec "$mpv"
fi

rules="float; pin; nofocus; center"
if [[ $KIND == screensaver ]]; then
  rules="${rules}; fullscreen"
else
  rules="${rules}; size 480 640"
fi
if [[ -n $MONITOR ]]; then
  rules="${rules}; monitor ${MONITOR}"
fi

hyprctl dispatch exec "[${rules}] ${mpv}" >/dev/null

for _ in $(seq 1 40); do
  if pgrep -f '[m]pv --title=higgsfield-signals-clip' >/dev/null 2>&1; then
    break
  fi
  sleep 0.05
done

while pgrep -f '[m]pv --title=higgsfield-signals-clip' >/dev/null 2>&1; do
  sleep 0.15
done
