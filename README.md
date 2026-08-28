# Tamagotchi

A desktop Tamagotchi for Omarchy. He stays on the **bottom of the focused window**, walks on keypresses, idles with a short loop, and dances when media is playing.

Drag him inside the window. Click to collapse (lie down) or expand. He turns at the window edges and never leaves that window’s bounds.

The **HF** chip builds an 8-bit sprite sheet from one character photo: `nano_banana_2` base sprite, then `seedance_2_0_mini` clips per action, then local frame cut / chroma-key. The pet reloads `~/.local/share/higgsfield.signals/spritesheet_16x12.png`.

## Install

```sh
omarchy plugin add git@github.com:higgsfield-ai/omarchy-pet.git --enable
omarchy-restart-shell
```

Kind changes need `omarchy plugin update higgsfield.signals --yes` (or `git pull` in the plugin dir) then `omarchy-restart-shell`. If the HF chip is missing after that:

```sh
omarchy plugin enable higgsfield.signals
omarchy-restart-shell
```

## Higgsfield CLI (required for generate)

```sh
# CLI on PATH, then log in once
higgsfield auth login

sudo pacman -S --needed ffmpeg python-pillow python-numpy
```

If walking does not react to keys, add your user to the `input` group so `watch-keys.py` can read `/dev/input`:

```sh
sudo usermod -aG input "$USER"
```

Then log out and back in.

## Test sprite generation on Omarchy

1. Put a character photo on the laptop, e.g. `~/Pictures/character.png`.
2. Confirm CLI auth: `higgsfield account` (or `higgsfield generate list --json`).
3. Click **HF** on the bar.
4. Paste the image path. Optional notes (hair, outfit).
5. Click **Walk test** first. That is one base still + one walk clip (~1–2 min), not the full 18-clip sheet.
6. Wait until the panel says `Saved …/spritesheet_16x12.png`. The pet should switch to the new walk cycle.
7. Full sheet: **Generate sheet** (18 clips, several minutes, billed per second).

Same pipeline from a terminal:

```sh
# Walk test (cheap)
omarchy-shell higgsfield.signals generateSpriteSmoke "$HOME/Pictures/character.png"

# Full 12-row sheet
omarchy-shell higgsfield.signals generateSprite "$HOME/Pictures/character.png"
```

Progress and errors: `~/.local/share/higgsfield.signals/generate.log`.
Strips and GIFs: `~/.local/share/higgsfield.signals/actions/` and `work/sheet/gifs/`.

Still-image generate (unrelated to the pet sheet):

```sh
omarchy-shell higgsfield.signals generate "a red sports car at dusk"
```

```sh
omarchy-shell higgsfield.signals ping
omarchy-shell higgsfield.signals collapse
```

## Develop

```sh
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" Service.qml Overlay.qml BarWidget.qml Panel.qml
node --test test/model.test.js
```

The sprite recipe is `skill/sprite-sheet-8bit/SKILL.md`. Runtime is `scripts/generate-sprite.py` → Higgsfield CLI → `skill/sprite-sheet-8bit/scripts/postprocess.py`.

## Iterate from a Mac

```sh
brew install fswatch
cp .env.example .env   # set OMARCHY_HOST=omarchy-hp
./scripts/sync.sh --validate
./scripts/watch.sh
```

## Remove

```sh
omarchy plugin remove higgsfield.signals
```
