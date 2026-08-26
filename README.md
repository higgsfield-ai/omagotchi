# 37signals

A random [37signals](https://37signals.com) principle on Omarchy’s native ASCII screensaver (`ttfx`), with DHH’s JOTA LMP2 driving a billboard road over it. Each billboard is one signal (00–37). The car is `car-body.png` + spinning `wheel.png`; exhaust and speed lines are drawn in the overlay.

On reveal or idle, the plugin writes an essay to `~/.config/omarchy/branding/screensaver.txt` and launches `omarchy-launch-screensaver force`. If the screensaver is already up, it only restarts `ttfx`. The first write copies your previous branding file to `screensaver.txt.higgsfield-bak`. The car appears once the screensaver windows exist (`org.omarchy.screensaver`) and disappears when they do. The overlay is click-through, so a key or mouse still dismisses `ttfx`.

This cannot draw on the PAM lock screen. When `idle.lock` fires, the lock takes over.

## Install

```sh
omarchy plugin remove higgsfield.pet
omarchy plugin add git@github.com:higgsfield-ai/omarchy-pet.git --enable
omarchy-restart-shell
```

Leave the stock screensaver **on**. The essay still runs in `ttfx`; the overlay adds the car and billboards.

Idle timings stay in `~/.config/omarchy/shell.json` (`idle.screensaver`, then `idle.lock`). Kind changes need `omarchy plugin update … --yes` then `omarchy-restart-shell`.

## Usage

```sh
omarchy-shell higgsfield.signals reveal
omarchy-shell higgsfield.signals next
omarchy-shell higgsfield.signals close
omarchy-shell higgsfield.signals ping
```

`reveal` picks a random signal for the ASCII animation and starts the car. Billboards then cycle the catalog, one signal per board, as they slide past. Any key or mouse dismisses both. `Super + Esc` also launches the screensaver.

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
