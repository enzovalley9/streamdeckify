# Streamdeckify: turn a Kindle into a Stream Deck

You are going to turn my Kindle into a touch panel of buttons (a "deck") for this computer. I tap a button on the Kindle and something happens here: an app opens, a shortcut is pressed, the music pauses.

This recipe is proven on a Kindle Paperwhite 2 (2013, firmware 5.12.2.1.1) driving a Mac mini and an Ubuntu PC, at about 140 ms from tap to action. Other Kindles should work the same way once they are jailbroken, but measure everything on mine instead of assuming.

## How it works (keep this design)

- The **computer** does the work. It draws the whole panel as one grayscale image at the Kindle's exact resolution, keeps the list of buttons and runs the actions.
- The **Kindle** is a dumb screen. It shows the image, reads raw touches and tells the computer where I tapped. It never decides what to run.
- They talk over my Wi-Fi with plain HTTP and a random token. The Kindle always starts the conversation (the computer never connects to the Kindle), so the Kindle's firewall can stay closed.
- The computer only runs actions from a fixed list in a config file. A tap sends coordinates, never commands.

## Ground rules

1. Go one step at a time. After each step, tell me what you found and what comes next.
2. Ask before you change the Kindle, install anything, open a firewall port or create a background service.
3. Never change privacy or security settings yourself. Tell me exactly what to click.
4. Everything stays on my local network: no cloud services, no accounts, no telemetry.
5. Back up the Kindle's storage before changing anything on it.
6. If something fails twice, stop, explain what you see and give me options. Don't guess in a loop.
7. Keep a README in the project folder and write down what you learn as you go.

## Step 0. What I have

Find out, and ask me only what you can't detect:

- My computer: OS and version, its IP on the Wi-Fi, and whether a firewall is on.
- The Kindle: when plugged in by USB it mounts as a drive on most models. Read `system/version.txt` for the firmware, and work out the model from the serial number (Settings > Device Options > Device Info). Tell me the model and generation.
- Back up the whole Kindle drive to a folder on my computer.
- Is it jailbroken? Signs: `documents/JAILBROKEN.txt`, or folders like `extensions/`, `koreader/` or `mrpackages/`.

**If it is not jailbroken:** open https://kindlemodding.org with me and find the current method for my exact model and firmware. Methods change every few months (in October 2026 a Paperwhite 2 on 5.12.2.x used WinterBreak2). I do the steps on the Kindle myself. You can read the official files and explain what each one does, but never download jailbreak files from anywhere else. Before we start, tell me the risks in one short paragraph and make sure the Kindle can't update itself halfway through. If I don't want to jailbreak, stop here and use the no-jailbreak recipe instead: {{SITE_URL}}/prompts/kindle-no-jailbreak.md

## Step 1. A shell on the Kindle

- Install KOReader for my model from its official GitHub releases and check the checksum. Besides being a great reader, it brings LuaJIT with FFI, an SSH server (dropbear) and FBInk. That's all we need on the Kindle.
- Get SSH working with key-only login: put my computer's public key in `koreader/settings/SSH/authorized_keys` and start KOReader's SSH server on port 2222 (from KOReader's menu, or with a launcher, below). Add a host alias `kindle` to my `~/.ssh/config`.
- Launchers: depending on the jailbreak, a shell script in `documents/` with a `# Name: ...` line at the top shows up in the library as a book and runs when I tap it (WinterBreak's scriptlets), or you write a KUAL extension. Make one called "SSH" that starts dropbear and prints the Kindle's IP on screen with `fbink`.
- Kindles ignore ping. Test the connection with TCP (ssh, nc), not ping.

Checkpoint: show me the output of `ssh kindle 'uname -a; df -h /mnt/us /var/local /'`.

## Step 2. Measure the Kindle (don't assume)

- Screen: `fbink -e` gives width, height, bits per pixel, rotation and dpi. Some FBInk builds have no image support (KOReader's often doesn't; the one that comes with the jailbreak usually does). Find one that can draw a PNG.
- Touch: find the touchscreen in `/proc/bus/input/devices` (an `/dev/input/eventN` with multitouch axes). Read its ranges and check whether they map 1:1 to pixels or are rotated or mirrored. Ask me to tap the four corners while you record raw events, and give me a long window, like 10 minutes: I will be slow.
- Software: see what's there (busybox, curl, lua, python). There's usually no Python. Use KOReader's LuaJIT for the client: through FFI it can do ioctl, poll and file IO.
- Free space on `/mnt/us`, `/var/local` and `/`.

Write all of this into the README.

## Step 3. The server on my computer

A small server in Python 3 (the standard library plus Pillow is enough, no web frameworks), listening on my LAN IP:

- `GET /layout`: plain text. First line, a version number. Then one line per button: `id x y w h type`.
- `GET /panel.png`: the whole panel at the Kindle's exact resolution, 8-bit grayscale, high contrast.
- `GET /tile/<id>?state=normal|pressed`: one button. Pressed is the same tile inverted.
- `POST /tap` with `x` and `y`: find the button, start its action in a background thread and answer straight away.
- Every request needs an `X-Token` header with a random token stored in a file only I can read.
- Buttons live in `config/buttons.json`: a grid (on a 6" Kindle, 3 columns by 4 rows is comfortable), each button `{id, label, icon, type, value}`, and `null` for an empty cell. Reload the file when it changes and bump the layout version.
- Action types: `app` (open an app by name), `url`, `key` (a shortcut like `cmd+shift+3`), `shortcut` (macOS Shortcuts), `command` (an argument list, never a shell string), `media` (play/pause), plus `refresh` and `exit`, which the Kindle handles itself.
- Draw each tile as an icon with the label under it: bold text sized to fit, icons turned gray (on macOS, the app's own icon or an SF Symbol).
- Log every action and how long it took.
- Run it as a user service that starts at login and restarts if it dies (a launchd agent on macOS, `systemd --user` on Linux). Ask me before installing it, and help me let it through the firewall.
- Optional but nice: answer UDP broadcasts on port 8788 so the Kindle finds the computer even if its IP changes. Have the Kindle send to my subnet's directed broadcast (like 192.168.1.255); 255.255.255.255 often doesn't arrive.

**macOS gotchas we already paid for**

- Pressing keys needs the Accessibility permission. Give it to a tiny helper app (a few lines of Swift that post CGEvents, signed ad hoc) that the server launches with `open`, not to Python. The Python that a launchd agent runs is often not the one listed in System Settings, and the permission silently doesn't apply. Rebuilding the helper changes its signature, so it needs the permission again.
- `screencapture` from a background service needs Screen Recording. Pressing cmd+shift+3 avoids that.
- AppleScript that controls another app (Spotify, a browser) shows an Automation prompt the first time. Warn me.

**Linux**: `xdotool` for keys, `gtk-launch` or `xdg-open` for apps, `playerctl` for media.

**Windows**: not tested yet. Propose something (PowerShell, AutoHotkey) and tell me it's new ground.

## Step 4. The client on the Kindle

Put it in `/mnt/us/streamdeckify/`: `deck.sh` (setup and cleanup) and `deck.lua` (the main loop, run with KOReader's LuaJIT).

`deck.sh`:

- Pause Amazon's interface so it neither draws over the panel nor reacts to taps. On the Paperwhite 2 that meant `killall -STOP awesome` and also `Xorg`: stopping only the window manager lets X clients repaint on top of the panel. Check what runs on my model before copying this.
- Keep the Kindle awake while the panel is open: `lipc-set-prop com.lab126.powerd preventScreenSaver 1`.
- On exit, always restore everything from a `trap`: continue the stopped processes, set preventScreenSaver back to 0 (if you forget, the power button stops putting it to sleep), repaint and go back to the home screen.
- If the Kindle's firewall blocks the discovery reply, open only that: `iptables -A INPUT -p udp --sport 8788 -j ACCEPT`.

`deck.lua`:

- Fetch the layout and the panel, draw it, and cache every tile in both states.
- Open the touchscreen and take it over with the `EVIOCGRAB` ioctl, so Amazon's interface gets no taps. Parse multitouch type B events and act on touch down.
- On a tap: draw the pressed tile with a fast partial refresh (FBInk `-W DU`), send `POST /tap`, then draw the normal tile again.
- Ignore a second tap on the same button within half a second. Some touch controllers split one tap in two.
- Every 15 taps or so, do a full flashing refresh to clear the ghosting.
- Check `/layout` every 60 seconds and repaint if the version changed.
- `exit` ends the loop (and the trap restores the Kindle). `refresh` repaints everything.

Launcher: a book in `documents/` called **Deck** that starts `deck.sh`, made the same way as the SSH one. Add a small deploy script on my computer that copies the client over SSH.

## Step 5. My buttons

Ask me what I want on it. Suggest a first grid for my system: browser, my AI app, terminal, chat, a dictation shortcut, music, play/pause, screenshot, lock screen and exit. Use the real app icons in gray when you can.

## Step 6. Test it with me

I tap every button while you watch the logs on both sides. Measure the time from tap to action (we got 130 to 240 ms; under 300 ms feels instant). Fix anything flaky before calling it done.

## Step 7. Hand it over

Finish the README: how to open and close the panel, add or move buttons, update the client, restart the server, and undo everything.

## Undo

Nothing here is permanent. Tap Exit or restart the Kindle to get Amazon's interface back. To remove it all, delete `/mnt/us/streamdeckify` and the launchers in `documents/`, and unload the service on the computer. The jailbreak has its own uninstall steps on kindlemodding.org.

## When it works

Take a photo of it on your desk and add it to the wall at {{SITE_URL}} (or post it with #streamdeckify). If you learned something new about your model, add it to the device list with a pull request: {{REPO_URL}}
