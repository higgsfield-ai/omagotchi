#!/usr/bin/env bash
# Play a prebuilt Higgsfield clip via mpv. Blocks until mpv exits.
# commit/fail: centered floating overlay, one play, then the window is gone.
# screensaver: fullscreen, one play.
set -euo pipefail

KIND=${1-}
FILE=${2-}
MONITOR=${3-}
LOG=${TMPDIR:-/tmp}/higgsfield-signals-play.log
TITLE=higgsfield-signals-clip

log() { printf '%s\n' "$*" | tee -a "$LOG" >&2; }

: >"$LOG"
log "play.sh kind=${KIND} file=${FILE} monitor=${MONITOR:-} at $(date -Iseconds 2>/dev/null || date)"

if [[ -z $KIND || -z $FILE ]]; then
  log "error: usage: play.sh <commit|fail|screensaver> <file> [monitor]"
  exit 1
fi
if [[ ! -f $FILE ]]; then
  log "error: missing clip file: ${FILE}"
  exit 1
fi
if ! command -v mpv >/dev/null 2>&1; then
  log "error: mpv not on PATH"
  exit 1
fi

pkill -f "[m]pv --title=${TITLE}" 2>/dev/null || true
sleep 0.05

MPV_ARGS=(
  mpv
  --title="$TITLE"
  --force-window=immediate
  --no-terminal
  --osc=no
  --osd-level=0
  --keep-open=no
  --loop=no
  --keepaspect=yes
  --no-border
  --ontop
  --no-input-default-bindings
  --cursor-autohide=always
  --
  "$FILE"
)

find_addr() {
  hyprctl -j clients 2>/dev/null | python3 -c '
import json, sys
title = sys.argv[1]
try:
    clients = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for c in clients:
    t = str(c.get("title") or "")
    it = str(c.get("initialTitle") or "")
    cls = str(c.get("class") or "")
    if title in t or title in it or t == title:
        print(c.get("address") or "")
        break
' "$TITLE" 2>/dev/null || true
}

float_window() {
  local addr=$1
  [[ -n $addr ]] || return 1
  hyprctl dispatch setfloating "address:${addr}" >/dev/null 2>&1 || true
  hyprctl dispatch pin "address:${addr}" >/dev/null 2>&1 || true
  if [[ -n ${MONITOR:-} ]]; then
    hyprctl dispatch movewindow "mon:${MONITOR}" "address:${addr}" >/dev/null 2>&1 \
      || hyprctl dispatch movewindow "mon:${MONITOR}" >/dev/null 2>&1 || true
  fi
  if [[ $KIND == screensaver ]]; then
    hyprctl dispatch fullscreen 1 "address:${addr}" >/dev/null 2>&1 || true
  else
    hyprctl dispatch resizewindowpixel "exact 480 640,address:${addr}" >/dev/null 2>&1 || true
    hyprctl dispatch centerwindow "address:${addr}" >/dev/null 2>&1 || true
  fi
  log "floated address=${addr}"
}

wait_for_window() {
  local i addr
  for i in $(seq 1 60); do
    addr=$(find_addr)
    if [[ -n $addr ]]; then
      printf '%s' "$addr"
      return 0
    fi
    sleep 0.05
  done
  return 1
}

# Prefer hyprctl exec so the player inherits the compositor session env.
if command -v hyprctl >/dev/null 2>&1; then
  rules="float; pin; nofocus; center"
  if [[ $KIND == screensaver ]]; then
    rules="${rules}; fullscreen"
  else
    rules="${rules}; size 480 640"
  fi
  if [[ -n ${MONITOR:-} ]]; then
    rules="${rules}; monitor ${MONITOR}"
  fi

  # Quote the path for a shell; Hyprland runs exec through sh -c.
  quoted=$(printf '%q' "$FILE")
  cmd="mpv --title=${TITLE} --force-window=immediate --no-terminal --osc=no --osd-level=0 --keep-open=no --loop=no --keepaspect=yes --no-border --ontop --no-input-default-bindings --cursor-autohide=always -- ${quoted}"
  log "hyprctl dispatch exec [${rules}] mpv …"
  if ! hyprctl dispatch exec "[${rules}] ${cmd}" >>"$LOG" 2>&1; then
    log "error: hyprctl dispatch exec failed"
  fi

  if addr=$(wait_for_window); then
    float_window "$addr"
    while pgrep -f "[m]pv --title=${TITLE}" >/dev/null 2>&1; do
      sleep 0.15
    done
    log "mpv exited"
    exit 0
  fi
  log "warn: mpv window never appeared via hyprctl; trying direct spawn"
fi

log "direct mpv spawn"
"${MPV_ARGS[@]}" >>"$LOG" 2>&1 &
mpid=$!

if command -v hyprctl >/dev/null 2>&1; then
  if addr=$(wait_for_window); then
    float_window "$addr"
  else
    log "warn: could not find mpv window to float"
  fi
fi

if ! wait "$mpid"; then
  log "error: mpv exited with status $?"
  exit 1
fi
log "mpv exited"
exit 0
