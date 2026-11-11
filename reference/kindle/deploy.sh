#!/bin/sh
# Copies the Kindle client over SSH and puts the "Deck" book in the library.
# Run it on the computer, from this folder, once the server has run once (it
# makes config/token). Needs a host called "kindle" in ~/.ssh/config.
# Usage: ./deploy.sh [computer-address]
#   With the computer's Wi-Fi address (like 192.168.1.x), the Kindle tries it
#   first and falls back to UDP discovery. Without it, discovery only.
#   The name and the ports come from config/buttons.json.
set -e
cd "$(dirname "$0")"

CONFIG=config/buttons.json
[ -f "$CONFIG" ] || { echo "No $CONFIG yet: copy one of the examples in config/ first."; exit 1; }
[ -s config/token ] || { echo "No config/token yet: start the server once and it makes one."; exit 1; }
NAME="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1])).get("name", "deck"))' "$CONFIG")"
PORT="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1])).get("port", 8787))' "$CONFIG")"
# The Kindle asks on the same UDP port the server answers on. 0 or null turns discovery off.
UDP_PORT="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1])).get("discovery_port", 8788) or 0)' "$CONFIG")"
TOKEN="$(cat config/token)"

# All of this ends up in a file that the Kindle runs as a shell script: check it first.
case "$NAME" in ''|*[!A-Za-z0-9_-]*) echo "The name in $CONFIG must be letters, digits, _ or -."; exit 1 ;; esac
case "$PORT$UDP_PORT" in *[!0-9]*) echo "The ports in $CONFIG must be numbers."; exit 1 ;; esac
case "$TOKEN" in ''|*[!A-Za-z0-9]*) echo "config/token doesn't look like a token: delete it and start the server again."; exit 1 ;; esac
case "$1" in *[!A-Za-z0-9.-]*) echo "Give the computer's address, like 192.168.1.x."; exit 1 ;; esac
URL=""
if [ -n "$1" ]; then URL="http://$1:$PORT"; fi
DISCOVERY=1
if [ "$UDP_PORT" = 0 ]; then
    [ -n "$URL" ] || { echo "Discovery is off in $CONFIG, so give the computer's address."; exit 1; }
    DISCOVERY=0
    UDP_PORT=8788
fi

# The Kindle's config holds the token: write it where only you can read it.
umask 077
TMPD="$(mktemp -d)"
trap 'rm -f "$TMPD/config"; rmdir "$TMPD"' EXIT
printf 'DECK_NAME=%s\nDECK_URL=%s\nDECK_TOKEN=%s\nDECK_UDP_PORT=%s\nDECK_DISCOVERY=%s\n' \
    "$NAME" "$URL" "$TOKEN" "$UDP_PORT" "$DISCOVERY" > "$TMPD/config"
ssh -o BatchMode=yes kindle 'mkdir -p /mnt/us/streamdeckify'
scp -q kindle/deck.sh kindle/deck.lua kindle/touch-test.lua "$TMPD/config" kindle:/mnt/us/streamdeckify/
scp -q kindle/launcher.sh kindle:/mnt/us/documents/Deck.sh
ssh -o BatchMode=yes kindle 'chmod 755 /mnt/us/streamdeckify/deck.sh; chmod 600 /mnt/us/streamdeckify/config'
echo "Done. Tap Deck in the Kindle's library. Computer: ${URL:-found by UDP discovery} (name: $NAME)"
