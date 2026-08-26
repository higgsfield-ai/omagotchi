# 37signals

A random [37signals](https://37signals.com) principle on Omarchy’s native ASCII screensaver (`ttfx`), with a pixel DHH running across it. The catalog is bundled (`Catalog.js` / `signals.json`, 00–37). The default pet is `atlas.png` (run cycle: row 0, frames 9–16). Custom generated pets come later; they will overwrite `atlas.png` + `atlas.json`.

On reveal or idle, the plugin writes the essay to `~/.config/omarchy/branding/screensaver.txt` and launches `omarchy-launch-screensaver force`. If the screensaver is already up, it only restarts `ttfx` so the next animation is the new signal. The first write copies your previous branding file to `screensaver.txt.higgsfield-bak`. DHH appears once the screensaver windows exist (`org.omarchy.screensaver`) and disappears when they do. The sprite is click-through, so a key or mouse still dismisses `ttfx`.

This cannot draw on the PAM lock screen. When `idle.lock` fires, the lock takes over.

## Install

```sh
omarchy plugin remove higgsfield.pet
omarchy plugin add git@github.com:higgsfield-ai/omarchy-pet.git --enable
omarchy-restart-shell
```

Leave the stock screensaver **on**. The essay still runs in `ttfx`; the overlay only adds the runner.

Idle timings stay in `~/.config/omarchy/shell.json` (`idle.screensaver`, then `idle.lock`). Kind changes need `omarchy plugin update … --yes` then `omarchy-restart-shell`.

## Usage

```sh
omarchy-shell higgsfield.signals reveal
omarchy-shell higgsfield.signals next
omarchy-shell higgsfield.signals close
omarchy-shell higgsfield.signals ping
```

`reveal` picks a random signal, writes it, and starts the ASCII animation. DHH runs along the bottom of each screen while the screensaver is up. Any key or mouse dismisses both. `Super + Esc` also launches the screensaver; whatever was last written to `screensaver.txt` is what `ttfx` animates, and the runner still appears.

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
