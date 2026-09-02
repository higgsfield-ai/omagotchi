#!/bin/sh
# Remove everything Higgsfield Omagotchi ever wrote to this machine.
# The plugin itself is removed by Omarchy; this clears the runtime data:
# CLI, venv, care state, photos, generated sheets, avatars, and media.
set -eu

DATA="$HOME/.local/share/higgsfield.signals"

if [ ! -d "$DATA" ]; then
  echo "Nothing to remove: $DATA does not exist."
  exit 0
fi

printf 'This deletes %s — avatars, care state, and generated media. Continue? [y/N] ' "$DATA"
read -r answer
case "$answer" in
  y|Y|yes|YES)
    rm -rf "$DATA"
    echo "Removed $DATA."
    echo "Finish with: omarchy plugin remove higgsfield.signals"
    ;;
  *)
    echo "Aborted; nothing was removed."
    ;;
esac
