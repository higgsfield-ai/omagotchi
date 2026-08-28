#!/usr/bin/env bash
# Open a native file picker and print the chosen image path.
set -euo pipefail

HOME_DIR="${HOME:-/tmp}"
START="${HOME_DIR}/Pictures"
if [[ ! -d $START ]]; then
  START="$HOME_DIR"
fi

pick_zenity() {
  zenity --file-selection \
    --title="Choose a character photo" \
    --filename="${START}/" \
    --file-filter="Images | *.png *.jpg *.jpeg *.webp *.gif *.bmp *.PNG *.JPG *.JPEG *.WEBP" \
    --file-filter="All files | *"
}

pick_kdialog() {
  kdialog --title "Choose a character photo" \
    --getopenfilename "$START/" "*.png *.jpg *.jpeg *.webp *.gif *.bmp"
}

pick_yad() {
  yad --file --filename="${START}/" --title="Choose a character photo" \
    --file-filter="Images | *.png *.jpg *.jpeg *.webp *.gif *.bmp"
}

if command -v zenity >/dev/null 2>&1; then
  pick_zenity
elif command -v kdialog >/dev/null 2>&1; then
  pick_kdialog
elif command -v yad >/dev/null 2>&1; then
  pick_yad
else
  echo "Install zenity to pick a photo: pacman -S zenity" >&2
  exit 1
fi
