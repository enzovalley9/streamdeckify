# Kindle reference code

Code for the [Kindle recipe](../../prompts/kindle.md): a server for the computer, a client for the Kindle, a deploy script and the background services. It comes from the first deck, a [Kindle Paperwhite 2](../../src/content/devices/kindle-paperwhite-2.md) that drives a Mac and an Ubuntu PC, cleaned up and renamed to match the recipe.

Your agent copies it and changes only what your Kindle and your computer need, instead of writing everything from scratch.

## For the agent

1. Copy this folder into the person's project folder, like `~/streamdeckify`, and work there.
2. Read this README and the recipe. Keep the design and the safety checks below.
3. Measure the Kindle (Step 2 of the recipe) and change what [Adapt it](#adapt-it) lists. Look for `MEASURE` in the code.
4. Follow the recipe one step at a time. It says when to ask before installing anything, opening a port or creating a service.
5. Write every change and every measurement in the project's README.

## What is in it

| File | What it does |
| --- | --- |
| `server/deck_server.py` | The server: Python 3 and Pillow, no frameworks. Draws the panel, serves it and runs the actions. |
| `config/buttons.macos.json`, `config/buttons.linux.json` | Example buttons. Copy one to `config/buttons.json`. |
| `kindle/deck.sh` | Pauses Amazon's interface, keeps the Kindle awake, runs `deck.lua`, and restores it all on exit. |
| `kindle/deck.lua` | The loop, for KOReader's LuaJIT: draws with FBInk, takes the touchscreen with `EVIOCGRAB` and reports taps. |
| `kindle/launcher.sh` | The **Deck** book in the library. `deploy.sh` copies it to `documents/Deck.sh`. |
| `kindle/touch-test.lua` | Prints the touchscreen's ranges and every touch, to measure a new Kindle. |
| `deploy.sh` | Copies the client to the Kindle over SSH and writes its config with the token. |
| `macos/keys/`, `macos/build-keys.sh` | A tiny helper app that presses keys, so the Accessibility permission sticks. |
| `macos/sf-symbol.swift` | Draws SF Symbols as icons. The server compiles it the first time a button uses one. |
| `service/local.streamdeckify.deck.plist` | Starts the server at login on macOS (launchd). |
| `service/streamdeckify.service` | The same on Linux (`systemd --user`). |

## How it works

```text
 Kindle: deck.sh + deck.lua                      computer: deck_server.py
 GET /layout, /panel.png, /tile/<id>   ──────▶   draws the panel from config/buttons.json
 POST /tap  x=..&y=..                  ──────▶   finds the button there, runs its action
 UDP "streamdeckify? <name>"           ──────▶   "streamdeckify <name> <port>"
```

- The Kindle always starts the conversation, so its firewall stays closed. The only exception is the answer to discovery, let in while the deck runs.
- `/layout` is plain text: a version on the first line, then `id x y w h type` for each button. The Kindle checks it every minute and redraws when the version changes.
- A tap is the first finger lifting close to where it landed. The tile turns inverted at once with a fast partial refresh, and every 15 taps a full refresh clears the ghosting.
- A second tap on the same button within half a second is ignored, because some touch controllers split one tap in two.
- `refresh` and `exit` never reach the computer: the Kindle handles them.

## Safety

- **A fixed list of actions.** A tap only sends coordinates. The server finds the button there and runs the action that `config/buttons.json` gives it. Its type must be one of `app`, `url`, `key`, `shortcut`, `command`, `media`, `refresh` or `exit`, or the server refuses the whole config. A `command` is a list of arguments and never goes through a shell.
- **A random token.** The server makes `config/token` on its first start, readable only by you, and `deploy.sh` copies it to the Kindle. Every request needs it in an `X-Token` header, except `/health`.
- **Local network only.** The server answers only addresses on the local network (10.x, 172.16 to 172.31, 192.168.x, link-local) and the computer itself, over HTTP and UDP. It listens on every interface so it keeps working when its IP changes. Set `listen` to the computer's Wi-Fi address to bind only there.
- **Plain words.** Button ids and types end up in file names and commands on the Kindle, so both sides accept only letters, digits, `_` and `-`.
- **Discovery trusts the network.** The Kindle sends its token to whichever computer answers discovery with the right name. On a network you don't trust, set `DECK_URL` and `DECK_DISCOVERY=0` in the Kindle's config.

## Adapt it

The code's defaults are the Paperwhite 2's. Measure yours first: [its device file](../../src/content/devices/kindle-paperwhite-2.md) shows what that looks like.

| What | Default | Where it lives |
| --- | --- | --- |
| Screen size | 758 x 1024 | `screen` in `config/buttons.json`. The drawing scales with it. |
| Grid | 3 columns by 4 rows | `columns` and `rows` in `config/buttons.json` |
| Touchscreen device | `/dev/input/event1` | `DECK_TOUCH` in the Kindle's config, `/mnt/us/streamdeckify/config` |
| How touches map to pixels | 1:1, no rotation | `to_screen()` in `kindle/deck.lua`. Check it with `kindle/touch-test.lua`. |
| An FBInk that draws PNGs | the jailbreak's | `FBINK_SOURCES` in `kindle/deck.sh` |
| What draws over the deck | Pillow, `awesome` and `Xorg` | the pause at the end of `kindle/deck.sh` and `restore()` |
| Wi-Fi interface | `wlan0` | the firewall rule in `kindle/deck.sh` and `broadcast_addresses()` in `kindle/deck.lua` |

Touch events are read with LuaJIT's FFI, so their size (16 bytes on a 32-bit Kindle) comes from the C struct and needs no change.

## Run it

### The computer

1. Install Pillow for the Python you will use, after asking: `python3 -m pip install --user Pillow`.
2. Copy an example: `cp config/buttons.macos.json config/buttons.json` (or the Linux one). Set `screen` to what you measured, and `name` to something short like `mac`.
3. Start it in a terminal: `python3 server/deck_server.py`. The first start makes `config/token`.
4. Check it from the same computer:

```sh
curl -s http://127.0.0.1:8787/health
curl -s -H "X-Token: $(cat config/token)" http://127.0.0.1:8787/layout
curl -s -H "X-Token: $(cat config/token)" -o panel.png http://127.0.0.1:8787/panel.png
```

5. If the computer's firewall is on, the person lets that Python accept incoming connections. Tell them where to click; don't change it yourself.
6. Once it works, install the service from `service/`, after asking. Each file has its install and undo commands at the top.

Edits to the buttons apply while it runs. Changes to `name`, `listen` or the ports need a restart. The log is `logs/server.log`, with every tap and how long each action took.

### The Kindle

1. SSH works and `kindle` is a host in `~/.ssh/config` (Step 1 of the recipe).
2. On the computer, from this folder: `./deploy.sh 192.168.1.x` with the computer's Wi-Fi address, or `./deploy.sh` to rely on discovery.
3. Tap **Deck** in the Kindle's library. **Exit** brings the Kindle back.

The Kindle's log is `/mnt/us/streamdeckify/deck.log`: one line per tap, with how long the Kindle and the computer took.

Several computers: run a server on each with its own `name` and token. On the Kindle, put each one's settings in `/mnt/us/streamdeckify/config-<name>`, and give each a launcher that runs `deck.sh <name>`.

## Buttons

`config/buttons.json` fills the grid row by row. `null` leaves a cell empty. Each button has:

| Field | What it is |
| --- | --- |
| `id` | A short unique word: letters, digits, `_` or `-` |
| `label` | The text under the icon. `\n` starts a new line, and the size fits itself. |
| `icon` | Optional. `app:<Name>` (that app's icon, macOS), `symbol:<name>` (an SF Symbol, macOS) or a PNG path relative to `config/`. On macOS, `app` buttons get their app's icon on their own. |
| `type` | One of the fixed list below |
| `value` | What the type needs |

| `type` | `value` | macOS | Linux |
| --- | --- | --- | --- |
| `app` | an app name | `open -a` | `gtk-launch`, with the name of its `.desktop` file |
| `url` | a URL | `open` | `xdg-open` |
| `key` | a combination like `cmd+shift+3` | the helper app, which needs Accessibility | `xdotool key`, which needs an X11 session |
| `shortcut` | the name of a Shortcut | `shortcuts run` | not available |
| `command` | a list of arguments, like `["pmset", "displaysleepnow"]` | run without a shell | run without a shell |
| `media` | nothing | pauses whatever plays in Spotify or Music, or resumes it | `playerctl play-pause` |
| `refresh` | nothing | the Kindle redraws everything | the same |
| `exit` | nothing | the Kindle closes the deck | the same |

Keys: `cmd`, `option`, `ctrl` and `shift` with one letter, digit, `space`, `return`, `tab`, `escape`, `delete`, an arrow, `home`, `end`, `pageup`, `pagedown` or `f1` to `f12`. A modifier can also go alone, like `option`.

## Gotchas we already paid for

- **macOS keys.** Key presses need the Accessibility permission. The server gives it to the helper app "Streamdeckify Keys", which it builds into `cache/` the first time. Given to Python, it didn't stick: launchd often runs a different Python from the one listed in System Settings. Rebuilding the helper changes its signature, so it needs the permission again.
- **macOS screenshots.** `screencapture` from a background service needs Screen Recording. Pressing `cmd+shift+3` doesn't.
- **macOS Automation.** `media` drives Spotify or Music with AppleScript. The first time, macOS asks to let the server control each app.
- **macOS icons.** `app:` icons come from the app's `.icns` file. An app without one gets a button with text only, and the log says why.
- **Linux keys.** `xdotool` needs an X11 session. If key buttons work from a terminal but not from the service, the service is missing `DISPLAY`.
- **The Kindle's power button.** With the deck open, it puts the Kindle to sleep. After waking it up, tap a `refresh` button, or leave the deck and open it again.

## Undo

- The Kindle: tap **Exit** or restart it. To remove it all, delete `/mnt/us/streamdeckify` and `documents/Deck.sh`.
- The computer: stop and remove the service with the undo commands in its file, then delete the project folder. On macOS, also remove "Streamdeckify Keys" from System Settings > Privacy & Security > Accessibility.

## Not tested yet

- This cleaned-up version on a Kindle. The code it comes from runs on the Paperwhite 2, and this version was tested on a computer with stand-ins for the Kindle's commands.
- Other Kindles, and Windows. If you get one working, tell us in a device file: the recipe explains how.
