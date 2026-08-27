# Tamagotchi

A desktop Tamagotchi for Omarchy. He stays on the **bottom of the focused window**, walks on keypresses, idles with a short loop, and dances when media is playing.

Drag him inside the window. Click to collapse (lie down) or expand. He turns at the window edges and never leaves that window’s bounds.

## Install

```sh
omarchy plugin add git@github.com:higgsfield-ai/omarchy-pet.git --enable
omarchy-restart-shell
```

Kind changes need `omarchy plugin update higgsfield.signals --yes` (or `git pull` in the plugin dir) then `omarchy-restart-shell`.

If walking does not react to keys, add your user to the `input` group so `watch-keys.py` can read `/dev/input`:

```sh
sudo usermod -aG input "$USER"
```

Then log out and back in.

## Usage

```sh
omarchy-shell higgsfield.signals ping
omarchy-shell higgsfield.signals collapse
```

## Develop

```sh
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" Service.qml Overlay.qml
node --test test/model.test.js
```

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
