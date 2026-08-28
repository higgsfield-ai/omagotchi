#!/usr/bin/env bash
# Open Omarchy's image picker (then a desktop dialog if needed) and print the path.
set -u

HOME_DIR="${HOME:-/tmp}"

collect_dirs() {
  local d sub n=0
  for d in "$HOME_DIR/Pictures" "$HOME_DIR/Downloads" "$HOME_DIR/Desktop"; do
    [[ -d $d ]] && printf '%s\0' "$d"
  done
  if [[ -d $HOME_DIR/Pictures ]]; then
    while IFS= read -r -d '' sub; do
      printf '%s\0' "$sub"
      n=$((n + 1))
      (( n >= 40 )) && break
    done < <(find -L "$HOME_DIR/Pictures" -mindepth 1 -maxdepth 2 -type d -print0 2>/dev/null)
  fi
}

pick_omarchy() {
  command -v omarchy-menu-images >/dev/null 2>&1 || return 1
  local dirs=()
  while IFS= read -r -d '' d; do
    dirs+=("$d")
  done < <(collect_dirs)
  (( ${#dirs[@]} > 0 )) || return 1
  omarchy-menu-images --filterable --show-labels "${dirs[@]}"
}

pick_zenity() {
  command -v zenity >/dev/null 2>&1 || return 1
  local start="$HOME_DIR/Pictures"
  [[ -d $start ]] || start="$HOME_DIR"
  zenity --file-selection \
    --title="Choose a character photo" \
    --filename="${start}/" \
    --file-filter="Images | *.png *.jpg *.jpeg *.webp *.gif *.bmp *.PNG *.JPG *.JPEG *.WEBP" \
    --file-filter="All files | *"
}

pick_kdialog() {
  command -v kdialog >/dev/null 2>&1 || return 1
  local start="$HOME_DIR/Pictures"
  [[ -d $start ]] || start="$HOME_DIR"
  kdialog --title "Choose a character photo" \
    --getopenfilename "$start/" "*.png *.jpg *.jpeg *.webp *.gif *.bmp"
}

pick_yad() {
  command -v yad >/dev/null 2>&1 || return 1
  local start="$HOME_DIR/Pictures"
  [[ -d $start ]] || start="$HOME_DIR"
  yad --file --filename="${start}/" --title="Choose a character photo" \
    --file-filter="Images | *.png *.jpg *.jpeg *.webp *.gif *.bmp"
}

if out=$(pick_omarchy); then
  [[ -n $out ]] && printf '%s\n' "$out"
  exit 0
fi
if out=$(pick_zenity); then
  [[ -n $out ]] && printf '%s\n' "$out"
  exit 0
fi
if out=$(pick_kdialog); then
  [[ -n $out ]] && printf '%s\n' "$out"
  exit 0
fi
if out=$(pick_yad); then
  [[ -n $out ]] && printf '%s\n' "$out"
  exit 0
fi

echo "Could not open a photo picker" >&2
exit 1
