# 37signals

A random [37signals](https://37signals.com) principle on the Omarchy screensaver overlay. The catalog is bundled (`signals.json`, 00–37) so nothing is fetched at idle time.

The overlay is a fullscreen layer-shell surface, same class as the image picker. It cannot draw on the PAM lock screen — when idle lock fires, that surface takes over.

## Install

On an Omarchy machine. If the Tamagotchi plugin was already installed, remove it first — the id changed:

```sh
omarchy plugin remove higgsfield.pet
omarchy plugin add git@github.com:higgsfield-ai/omarchy-pet.git --enable
omarchy-restart-shell
```

Turn off the stock ASCII screensaver so it does not stack on top of the overlay:

```sh
omarchy toggle screensaver
```

Idle timings stay in `~/.config/omarchy/shell.json` (`idle.screensaver`, then `idle.lock`).

## Usage

After the screensaver timeout, a random signal fills the screen. Click or any key dismisses it. While it is up, it rotates to another signal every 45 seconds.

```sh
omarchy-shell higgsfield.signals reveal
omarchy-shell higgsfield.signals show '{}'
omarchy-shell higgsfield.signals next
omarchy-shell higgsfield.signals close
omarchy-shell shell summon higgsfield.signals '{}'
omarchy-shell shell hide higgsfield.signals
```

Bare `show` with no argument is swallowed by Qt `Window.show()`. Pass `'{}'` or use `reveal`.

`Super + Esc` still launches the stock terminal screensaver.

## Develop

Follow [Develop a Plugin](https://omarchyplugins.com/develop.html). This plugin is a keepLoaded `panel` (same contract as the OSD). There is no bar widget.

```sh
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" Overlay.qml
node --test test/model.test.js
```

Saved files under `~/.config/omarchy/plugins/` reload automatically. Manifest kind changes need `omarchy plugin update … --yes` then `omarchy-restart-shell`.

## Iterate from a Mac

QML only loads inside `omarchy-shell` on the HP. Keep git on the Mac; push files over SSH. Do **not** symlink the plugin directory.

**Fastest for UI:** Cursor Remote SSH, open `~/.config/omarchy/plugins/higgsfield.signals` on the HP. Save → overlay reloads.

**Fastest while git stays on the Mac:** one-time SSH, then watch + rsync.

`~/.ssh/config`:

```
Host omarchy-hp
  HostName 192.168.x.x
  User <hp-user>
  ControlMaster auto
  ControlPath ~/.ssh/cm-%r@%h:%p
  ControlPersist 10m
```

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

Logs:

```sh
qs log -p "$OMARCHY_PATH/shell" --tail 100
```

A wedged shell: `omarchy-restart-shell`.

## Remove

```sh
omarchy plugin remove higgsfield.signals
```
