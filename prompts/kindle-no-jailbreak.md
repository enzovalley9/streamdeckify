# Streamdeckify: a Kindle deck without jailbreaking it

Status: experimental. Whatever happens, please tell us how it went (see the end).

You are going to turn my Kindle into a panel of buttons for this computer without installing anything on the Kindle. Its built-in web browser opens a page that this computer serves on my Wi-Fi, and each button on that page asks the computer to run one action.

It will be slower than the jailbroken version (the Kindle's browser is old) and the Kindle may fall asleep after a while. It's still a good panel, and nothing on the Kindle changes. The jailbroken recipe, if I change my mind: {{SITE_URL}}/prompts/kindle.md

## How it works (keep this design)

- The computer keeps the list of buttons and runs the actions, only from a fixed list in a config file. The page can only say "button 3 was pressed", never send a command.
- The page is served on my local network with a random token in its address. Nothing goes to the cloud.

## Ground rules

1. Go one step at a time. After each step, tell me what you found and what comes next.
2. Ask before you install anything, open a firewall port or create a background service.
3. Never change privacy or security settings yourself. Tell me exactly what to click.
4. Everything stays on my local network: no cloud services, no accounts, no telemetry.
5. If something fails twice, stop, explain what you see and give me options.
6. Keep a README in the project folder and write down what you learn as you go.

## Step 0. What I have

- My computer: OS and version, its IP on the Wi-Fi, and whether a firewall is on.
- The Kindle: model and firmware (Settings > Device Options > Device Info). Check that it has a web browser: on most Kindles it's called "Experimental Browser" or "Web Browser", in the menu or on the home screen. If mine has none, tell me and stop.

## Step 1. The server on my computer

A small Python 3 server, standard library only, listening on my LAN IP, port 8787:

- `GET /d/<token>/` serves the deck page. The token is random and goes in the address, because the Kindle's browser can't send custom headers reliably. Treat the full address like a password.
- `GET /d/<token>/tap/<id>` runs the action for that button and answers `204 No Content`, so the page doesn't navigate away.
- `GET /k`: a short address that redirects to the full one, answered only for devices on my LAN, so I don't have to type the token on the Kindle.
- Buttons live in `config/buttons.json` as a grid, each `{id, label, type, value}`.
- Action types: `app`, `url`, `key` (a shortcut), `shortcut` (macOS Shortcuts), `command` (an argument list, never a shell string), `media` (play/pause).
- On macOS, pressing keys needs the Accessibility permission. Give it to a tiny helper app (Swift, CGEvent, signed ad hoc) that the server launches, not to Python: the Python a background service runs is often not the one listed in System Settings. On Linux use `xdotool`, `xdg-open` and `playerctl`.
- Log every action and how long it took.
- Run it as a user service that starts at login. Ask me first, and help me let it through the firewall.

## Step 2. The page: an old browser on an e-ink screen

- Plain HTML and CSS, with a little inline JavaScript in ES5 only: no arrow functions, no `let` or `const`, no `fetch`, no Promises, no modules. Use `XMLHttpRequest`.
- Lay it out with a table or inline blocks (no CSS grid, careful with flexbox). Before designing, show me a test page that prints `window.innerWidth` and `window.innerHeight` so we size it for the real screen.
- Huge targets: 3 columns by 4 rows filling the screen. Black on white, thick borders, bold labels. No animations, no gradients, no web fonts, small images or none.
- Feedback: when I tap, invert the button at once, send the request, and put it back when the answer arrives. If it fails, show a short error on the button.
- Without JavaScript, every button should still work as a plain link.
- Avoid accidental text selection and zoom.

## Step 3. Keep it awake

On some firmware, typing `~ds` in the Kindle's search bar and pressing enter turns off the screensaver until the next restart. It doesn't work on every version: ask me to try it. If it doesn't, the Kindle will sleep after a few minutes and I'll wake it when I need it. Keep it plugged in either way.

## Step 4. Open it on the Kindle

Tell me exactly what to type in the Kindle's browser (the short address) and how to bookmark it. If the browser has a full screen or article mode, tell me how to turn it on.

## Step 5. My buttons

Ask me what I want. Suggest a first grid for my system: browser, my AI app, terminal, chat, music, play/pause, screenshot, lock screen.

## Step 6. Test it with me

I tap every button while you watch the log. Measure the time from tap to action and tell me (expect half a second to two seconds).

## Step 7. Hand it over

Finish the README: how to start and stop the server, add buttons and undo everything.

## Undo

Nothing changed on the Kindle. Delete the bookmark, then stop and remove the service on the computer.

## Tell us how it went

This recipe is still experimental. Open an issue with your Kindle model, firmware, what worked and what didn't: {{REPO_URL}}/issues/new?template=add-device.yml
