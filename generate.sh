#!/usr/bin/env bash
# Run higgsfield CLI, download the first result into ~/Pictures/higgsfield, print one JSON line.
set -euo pipefail

PROMPT=${1-}
MODEL=${2:-nano_banana_2}
OUT_DIR=${3:-"${HOME}/Pictures/higgsfield"}
LOG=${TMPDIR:-/tmp}/higgsfield-signals-generate.log

if [[ -z $PROMPT ]]; then
  printf '%s\n' '{"ok":false,"error":"empty prompt"}'
  exit 1
fi

mkdir -p "$OUT_DIR" || {
  printf '%s\n' "{\"ok\":false,\"error\":\"cannot create ${OUT_DIR}\"}"
  exit 1
}
: >"$LOG"

find_hf() {
  if command -v higgsfield >/dev/null 2>&1; then
    command -v higgsfield
    return
  fi
  if command -v hf >/dev/null 2>&1; then
    command -v hf
    return
  fi
  local p
  for p in \
    "${HOME}/.local/bin/higgsfield" \
    /usr/local/bin/higgsfield \
    /opt/homebrew/bin/higgsfield \
    "${HOME}/.nvm/versions/node/"*/bin/higgsfield
  do
    # shellcheck disable=SC2086
    for m in $p; do
      if [[ -x $m ]]; then
        printf '%s\n' "$m"
        return
      fi
    done
  done
  return 1
}

HF=$(find_hf) || {
  printf '%s\n' '{"ok":false,"error":"higgsfield CLI not found. Install: brew install higgsfield-ai/tap/higgsfield && higgsfield auth login"}'
  exit 1
}

JOB_JSON=$(mktemp)
ERR=$(mktemp)
trap 'rm -f "$JOB_JSON" "$ERR"' EXIT

echo "hf=${HF} model=${MODEL}" >>"$LOG"
echo "prompt=${PROMPT}" >>"$LOG"

set +e
"$HF" generate create "$MODEL" --prompt "$PROMPT" --wait --json >"$JOB_JSON" 2>"$ERR"
status=$?
set -e
cat "$ERR" >>"$LOG" || true
cat "$JOB_JSON" >>"$LOG" || true

if [[ $status -ne 0 ]]; then
  python3 - "$ERR" <<'PY'
import json, sys
err = open(sys.argv[1], encoding="utf-8", errors="replace").read().strip()
if not err:
    err = "higgsfield generate failed"
print(json.dumps({"ok": False, "error": err[-800:]}))
PY
  exit 1
fi

python3 - "$JOB_JSON" "$OUT_DIR" "$MODEL" <<'PY'
import json, os, shutil, subprocess, sys, time, urllib.request

job_path, out_dir, model = sys.argv[1], sys.argv[2], sys.argv[3]
raw = open(job_path, encoding="utf-8").read().strip()
if not raw:
    print(json.dumps({"ok": False, "error": "empty CLI JSON"}))
    sys.exit(1)

try:
    data = json.loads(raw)
except json.JSONDecodeError:
    # Sometimes CLI prints a URL line; accept bare https.
    for line in raw.splitlines():
        line = line.strip()
        if line.startswith("http://") or line.startswith("https://"):
            data = {"result_url": line}
            break
    else:
        print(json.dumps({"ok": False, "error": "could not parse CLI output", "raw": raw[-400:]}))
        sys.exit(1)

def extract_url(node):
    if node is None:
        return ""
    if isinstance(node, str):
        return node if node.startswith("http") else ""
    if isinstance(node, list):
        for item in node:
            u = extract_url(item)
            if u:
                return u
        return ""
    if isinstance(node, dict):
        for key in ("result_url", "url", "output_url", "image_url", "video_url"):
            val = node.get(key)
            if isinstance(val, str) and val.startswith("http"):
                return val
        for key in ("results", "output", "outputs", "assets", "data", "job", "jobs"):
            if key in node:
                u = extract_url(node.get(key))
                if u:
                    return u
        # Nested media objects
        for key in ("media", "images", "files"):
            if key in node:
                u = extract_url(node.get(key))
                if u:
                    return u
    return ""

url = extract_url(data)
if not url:
    print(json.dumps({"ok": False, "error": "no result URL in CLI JSON", "raw": raw[-400:]}))
    sys.exit(1)

ext = ".png"
lower = url.lower().split("?", 1)[0]
for candidate, e in ((".mp4", ".mp4"), (".webm", ".webm"), (".jpg", ".jpg"), (".jpeg", ".jpg"), (".webp", ".webp"), (".png", ".png")):
    if lower.endswith(candidate):
        ext = e
        break

stamp = time.strftime("%Y%m%d-%H%M%S")
safe_model = "".join(ch if ch.isalnum() or ch in "-_" else "-" for ch in model)[:40]
path = os.path.join(out_dir, f"{stamp}-{safe_model}{ext}")

req = urllib.request.Request(url, headers={"User-Agent": "higgsfield.signals-omarchy/0.12"})
with urllib.request.urlopen(req, timeout=120) as resp, open(path, "wb") as fh:
    while True:
        chunk = resp.read(1024 * 256)
        if not chunk:
            break
        fh.write(chunk)

opener = shutil.which("xdg-open")
if opener:
    subprocess.Popen(
        [opener, path],
        start_new_session=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

print(json.dumps({"ok": True, "path": path, "url": url, "model": model}))
PY
