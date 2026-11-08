#!/bin/sh
# Copies the Kindle client over SSH and puts the "Deck" book in the library.
# Run it on the computer, from this folder, once the server has run once (it
# makes config/token). Needs a host called "kindle" in ~/.ssh/config.
# Usage: ./deploy.sh [computer-address]
#   With the computer's Wi-Fi address (like 192.168.1.x), the Kindle tries it
#   first and falls back to UDP discovery. Without it, discovery only.
set -e
cd "$(dirname "$0")"

CONFIG=config/buttons.json
[ -f "$CONFIG" ] || { echo "No $CONFIG yet: copy one of the examples in config/ first."; exit 1; }
[ -s config/token ] || { echo "No config/token yet: start the server once and it makes one."; exit 1; }
NAME="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1])).get("name", "deck"))' "$CONFIG")"
PORT="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1])).get("port", 8787))' "$CONFIG")"
TOKEN="$(cat config/token)"
URL=""
if [ -n "$1" ]; then URL="http://$1:$PORT"; fi

# The Kindle's config holds the token: write it where only you can read it.
umask 077
TMPD="$(mktemp -d)"
trap 'rm -f "$TMPD/config"; rmdir "$TMPD"' EXIT
printf 'DECK_NAME=%s\nDECK_URL=%s\nDECK_TOKEN=%s\n' "$NAME" "$URL" "$TOKEN" > "$TMPD/config"
ssh -o BatchMode=yes kindle 'mkdir -p /mnt/us/streamdeckify'
scp -q kindle/deck.sh kindle/deck.lua kindle/touch-test.lua "$TMPD/config" kindle:/mnt/us/streamdeckify/
scp -q kindle/launcher.sh kindle:/mnt/us/documents/Deck.sh
ssh -o BatchMode=yes kindle 'chmod 755 /mnt/us/streamdeckify/deck.sh; chmod 600 /mnt/us/streamdeckify/config'
echo "Done. Tap Deck in the Kindle's library. Computer: ${URL:-found by UDP discovery} (name: $NAME)"
