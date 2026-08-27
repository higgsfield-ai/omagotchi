# 37signals

A random [37signals](https://37signals.com) principle on Omarchy’s native ASCII screensaver (`ttfx`), plus a desktop Tamagotchi of DHH in the racing suit.

On reveal or idle, the plugin writes an essay to `~/.config/omarchy/branding/screensaver.txt` and launches `omarchy-launch-screensaver force`. The first write copies your previous branding file to `screensaver.txt.higgsfield-bak`. The screensaver is ASCII only — no car overlay.

The pet stays on the **bottom of the focused window** (`hyprctl activewindow`) and turns before it can leave that window’s edges. It walks on every keypress (evdev), idles with a looping stand animation, and when media is playing it dances to the PipeWire waveform (`PwNodePeakMonitor` on the default sink). Loud peaks trigger a dash. Drag it; click it to collapse (lie down) or expand. The pet hides while a clip or the screensaver is up.

Prebuilt Higgsfield clips of DHH play on events. **Commit** and **fail** are a centered floating overlay: one play (~5s), then the window closes. **Idle / reveal** plays the landscape screensaver clip fullscreen, also once. `Super + Esc` still launches stock `ttfx` with the latest essay (the plugin writes `screensaver.txt` first).

This cannot draw on the PAM lock screen. When `idle.lock` fires, the lock takes over.

## Install

```sh
omarchy plugin remove higgsfield.pet
omarchy plugin add git@github.com:higgsfield-ai/omarchy-pet.git --enable
omarchy-restart-shell
```

Leave the stock screensaver **on**. This plugin uses it for the essays.

Idle timings stay in `~/.config/omarchy/shell.json` (`idle.screensaver`, then `idle.lock`). Kind changes need `omarchy plugin update … --yes` then `omarchy-restart-shell`.

If walking does not react to keys, add your user to the `input` group so `watch-keys.py` can read `/dev/input`:

```sh
sudo usermod -aG input "$USER"
```

Then log out and back in.

## Usage

```sh
omarchy-shell higgsfield.signals reveal
omarchy-shell higgsfield.signals next
omarchy-shell higgsfield.signals close
omarchy-shell higgsfield.signals ping
omarchy-shell higgsfield.signals event commit
omarchy-shell higgsfield.signals event fail
omarchy-shell higgsfield.signals event screensaver
```

`reveal` / `next` pick a random essay, write it to `screensaver.txt`, and play the screensaver clip. Commit and fail debounce for 8 seconds so a burst of hooks does not stack windows.

### Trigger each clip

| Clip | How to play it |
|---|---|
| **1. commit** (centered overlay, once) | `omarchy-shell higgsfield.signals event commit` — or copy `hooks/post-commit` into a repo’s `.git/hooks/post-commit`, then `git commit`. |
| **2. fail** (centered overlay, once) | `omarchy-shell higgsfield.signals event fail` — or call that from a test/CI wrapper on non-zero exit. |
| **3. screensaver** (fullscreen, once) | Wait for Omarchy idle, or `omarchy-shell higgsfield.signals reveal`. Stock ASCII is still `Super + Esc`. |

Need `mpv` on the path (Omarchy ships it). Overlay clips need Hyprland so the player can float and pin; they do not steal keyboard focus.

## Develop

Follow [Develop a Plugin](https://omarchyplugins.com/develop.html). This plugin is a keepLoaded `overlay` plus a `service`.

```sh
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" Service.qml Overlay.qml
node --test test/model.test.js
```

Manifest kind changes need `omarchy plugin update … --yes` then `omarchy-restart-shell`.

## Iterate from a Mac

QML only loads inside `omarchy-shell` on the HP. Keep git on the Mac; push files over SSH. Do **not** symlink the plugin directory.

```sh
brew install fswatch
cp .env.example .env   # set OMARCHY_HOST=omarchy-hp
./scripts/sync.sh --validate
./scripts/watch.sh
```

On the HP, first time only:

```sh
omarchy plugin enable higgsfield.signals
omarchy-restart-shell
```

## Remove

```sh
omarchy plugin remove higgsfield.signals
```

To restore the previous ASCII logo:

```sh
mv ~/.config/omarchy/branding/screensaver.txt.higgsfield-bak \
   ~/.config/omarchy/branding/screensaver.txt
```
