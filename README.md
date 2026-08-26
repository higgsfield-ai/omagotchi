# 37signals

A random [37signals](https://37signals.com) principle on Omarchy’s native ASCII screensaver (`ttfx`). The catalog is bundled (`Catalog.js` / `signals.json`, 00–37).

On reveal or idle, the plugin writes the essay to `~/.config/omarchy/branding/screensaver.txt` and launches `omarchy-launch-screensaver force`. If the screensaver is already up, it only restarts `ttfx` so the next animation is the new signal. The first write copies your previous branding file to `screensaver.txt.higgsfield-bak`.

This cannot draw on the PAM lock screen. When `idle.lock` fires, the lock takes over.

## Install

```sh
omarchy plugin remove higgsfield.pet
omarchy plugin add git@github.com:higgsfield-ai/omarchy-pet.git --enable
omarchy-restart-shell
```

Leave the stock screensaver **on**. This plugin uses it rather than stacking a QML overlay.

Idle timings stay in `~/.config/omarchy/shell.json` (`idle.screensaver`, then `idle.lock`).

## Usage

```sh
omarchy-shell higgsfield.signals reveal
omarchy-shell higgsfield.signals next
omarchy-shell higgsfield.signals close
omarchy-shell higgsfield.signals ping
```

`reveal` picks a random signal, writes it, and starts the ASCII animation. Any key or mouse dismisses it the same way as the stock screensaver. `Super + Esc` also launches the screensaver; whatever was last written to `screensaver.txt` is what `ttfx` animates.

## Develop

Follow [Develop a Plugin](https://omarchyplugins.com/develop.html). This plugin is a headless `service`.

```sh
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" Service.qml
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
