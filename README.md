# Tamagotchi

A desktop Tamagotchi for Omarchy. He stays on the **bottom of the focused window**, walks on keypresses, idles with a short loop, and dances when media is playing.

Drag him inside the window. Click to collapse (lie down) or expand. He turns at the window edges and never leaves that window’s bounds.

The **HF** chip is the whole product: log in once, upload a photo, **Generate my avatar**. The new sheet replaces the pet on your desktop. Progress shows in the panel and on the chip.

## Install

```sh
omarchy plugin add git@github.com:higgsfield-ai/omarchy-pet.git --enable
omarchy-restart-shell
```

Update:

```sh
omarchy plugin update higgsfield.signals --yes
```

The **HF** chip lands on the right of the bar by itself. Restart the shell only if the chip is still missing after the update.

No extra packages. The plugin downloads the Higgsfield CLI and Python image libs into `~/.local/share/higgsfield.signals` on first use. Omarchy already has `ffmpeg`.

## Use

1. Click **HF** on the bar.
2. Click **Generate my avatar**. A browser opens for Higgsfield login.
3. After login, the photo well unlocks. Choose a picture.
4. Click **Generate my avatar** again. Keep the panel open — percent and step text update as clips finish.
5. When it says **Tamagotchi ready**, the desktop pet is the new one.

A full run is 18 short video clips (several minutes). Logs: `~/.local/share/higgsfield.signals/generate.log`.

If walking does not react to keys, add your user to the `input` group and log out:

```sh
sudo usermod -aG input "$USER"
```

## Develop

```sh
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" Service.qml Overlay.qml BarWidget.qml Panel.qml
node --test test/model.test.js
```

Recipe: `skill/sprite-sheet-8bit/SKILL.md`. Runtime: `scripts/runtime.py` (CLI + deps) → `scripts/generate-sprite.py` → `skill/sprite-sheet-8bit/scripts/postprocess.py`.

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
