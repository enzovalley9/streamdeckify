# Streamdeckify: turn any screen into a Stream Deck

You are going to turn one of my old devices into a panel of buttons (a "deck") for this computer. I press a button on that device and something happens here: an app opens, a shortcut is pressed, the lights go on.

It works with anything that has a web browser (old iPads and iPhones, Android phones and tablets, e-readers, smart TVs, game consoles) or that can run code (a Raspberry Pi with a screen, a jailbroken e-reader, Android with Termux). Touchscreen or not: TVs have remotes, some e-readers have a 5-way pad, and everything takes a keyboard.

## How it works (keep this design)

- The computer keeps the list of buttons and runs the actions, only from a fixed list in a config file. The device can only say "button 3 was pressed", never send a command.
- The device shows the buttons and reports what I press.
- They talk over my Wi-Fi with a random token. Nothing goes to the cloud.

## Ground rules

1. Go one step at a time. After each step, tell me what you found and what comes next.
2. Ask before you change the device, install anything, open a firewall port or create a background service.
3. Never change privacy or security settings yourself, on the computer or the device. Tell me exactly what to click.
4. Everything stays on my local network: no cloud services, no accounts, no telemetry.
5. If something fails twice, stop, explain what you see and give me options.
6. Keep a README in the project folder and write down what you learn as you go.

## Step 0. Interview me

Ask one short question at a time, and suggest likely answers:

1. The device: brand, model, year, OS version, and which browser it has (or whether it can run code).
2. The screen: size, the orientation I want, e-ink or not.
3. How I press things on it: touch, a remote or D-pad, physical buttons, a keyboard.
4. Can it stay plugged in and awake?
5. My computer: OS and version.
6. What I want the buttons to do.

## Step 1. Pick the approach and tell me why

- **Browser deck** (the default): the computer serves a page and the device opens it. Works almost everywhere.
- **Native client**: if the device can run code and its browser is bad or missing (a jailbroken Kindle or Kobo, a Raspberry Pi, Termux on Android), a small client that draws the panel and reads input directly is faster. For Kindles there's a dedicated recipe: {{SITE_URL}}/prompts/kindle.md
- **An existing app**: if the device already runs something that can send an HTTP request when a button is pressed, we can skip the page. Only if it's genuinely simpler.

## Step 2. The server on my computer

A small server in Python 3 (standard library, plus Pillow only if you draw images), listening on my LAN IP:

- It serves the deck page (browser approach) and receives presses (`GET /d/<token>/tap/<id>` answering `204 No Content`, or `POST /tap` with a token header for native clients).
- Old browsers can't always send custom headers, so for pages put a random token in the address and treat that address like a password. Offer a short address (like `/k`) that redirects to it, answered only on my LAN.
- Buttons live in `config/buttons.json` as a grid, each `{id, label, icon, type, value}`. Action types: `app`, `url`, `key` (a shortcut like `cmd+shift+3`), `shortcut` (macOS Shortcuts), `command` (an argument list, never a shell string), `media` (play/pause), and `homeassistant` (call a Home Assistant service with a long-lived token stored on the computer) if I use it.
- Log every action and how long it took.
- Run it as a user service that starts at login and restarts if it dies (launchd on macOS, `systemd --user` on Linux, Task Scheduler on Windows). Ask me first, and help me let it through the firewall.

macOS gotchas: pressing keys needs the Accessibility permission, which should go to a tiny helper app (Swift, CGEvent, signed ad hoc) that the server launches, not to Python, because the Python a background service runs is often not the one listed in System Settings. `screencapture` from a service needs Screen Recording; pressing cmd+shift+3 doesn't. Controlling other apps with AppleScript shows an Automation prompt the first time.

Linux: `xdotool`, `xdg-open` or `gtk-launch`, `playerctl`. Windows: still new ground for this project, so say so and propose something (PowerShell, AutoHotkey).

## Step 3. The page, made for this device

Build it for the device I have, not for a modern laptop. First show me a test page that prints its CSS width, height, pixel ratio and user agent, and for non-touch devices the key codes it receives.

- **Old browsers** (Safari on iOS 9 to 12, e-reader browsers, old Android WebViews, TV browsers): ES5, `XMLHttpRequest`, no modules. Check each feature before you rely on it, and test on the device early.
- **Touch**: huge targets, an instant change on press (invert the button), no hover effects, `touch-action: manipulation` against double-tap zoom, no text selection.
- **No touch** (remote, D-pad, 5-way, keyboard): every button focusable, arrow keys move the focus around the grid like a TV menu, Enter or OK presses, a thick and obvious focus ring, and focus on the first button when the page loads. If the remote has number keys, map 1 to 9 to the first nine buttons.
- **E-ink**: pure black and white, no animations, no gradients, repaint as little as possible.
- **Full screen and awake**: a web app manifest so I can add it to the home screen (iOS, Android), kiosk mode or screen pinning (Android), the Screen Wake Lock API where it exists, and the device's own display settings otherwise. Tell me which settings to change; don't change them yourself.
- **Feedback**: show that the computer got the press, and show the error if it didn't. For live states (mic muted, music playing), poll every few seconds instead of holding connections open on old devices.

## Step 4. My buttons

Ask me what I want on it. Suggest a first grid for my system and for the size of the screen: browser, my AI app, terminal, chat, a dictation shortcut, music, play/pause, screenshot, lock screen.

## Step 5. Test it with me

I press every button while you watch the log. Measure the time from press to action and tell me. Fix anything flaky before calling it done.

## Step 6. Hand it over

Finish the README: how to open the deck on the device, add or move buttons, restart the server, and undo everything.

## Undo

Remove the bookmark or home screen icon on the device, then stop and remove the service on the computer. If you installed anything on the device, list how to remove it.

## When it works

Take a photo and add it to the wall at {{SITE_URL}} (or post it with #streamdeckify). Your device probably isn't on the list yet: add it with a pull request, so the next person with the same one gets it working in minutes: {{REPO_URL}}
