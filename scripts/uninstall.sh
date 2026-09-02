#!/bin/sh
# Remove everything Higgsfield Omagotchi ever wrote to this machine.
# The plugin itself is removed by Omarchy; this clears the runtime data:
# CLI, venv, care state, photos, generated sheets, avatars, and media.
set -eu

DATA="$HOME/.local/share/higgsfield-omagotchi"
# A machine that never ran the plugin after the omagotchi rename still keeps
# its data under the old id, so clear that too rather than leaving it stranded.
LEGACY="$HOME/.local/share/higgsfield.signals"
[ -d "$DATA" ] || DATA="$LEGACY"

if [ ! -d "$DATA" ]; then
  echo "Nothing to remove: $DATA does not exist."
  exit 0
fi

printf 'This deletes %s — avatars, care state, and generated media. Continue? [y/N] ' "$DATA"
read -r answer
case "$answer" in
  y|Y|yes|YES)
    rm -rf "$DATA" "$LEGACY"
    echo "Removed $DATA."
    echo "Finish with: omarchy plugin remove higgsfield-omagotchi"
    ;;
  *)
    echo "Aborted; nothing was removed."
    ;;
esac
