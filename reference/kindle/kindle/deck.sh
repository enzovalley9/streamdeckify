#!/bin/sh
# Streamdeckify reference client: starts the deck on a jailbroken Kindle and
# puts Amazon's interface back the way it was when the deck ends.
# Usage: deck.sh [profile]
#   Reads /mnt/us/streamdeckify/config, or config-<profile> if you give one
#   (one profile per computer). Runs as root, from the "Deck" book in the
#   library (launcher.sh) or over SSH.
#
# Pausing the interface follows KOReader's platform/kindle/koreader.sh for
# recent firmware: Pillow off, the title bar shrunk with wmctrl and the window
# manager (awesome) stopped. This also stops Xorg, or X clients repaint parts
# of the screen over the deck. MEASURE: check what runs on your Kindle first.

PROFILE="$1"
case "$PROFILE" in
    *[!A-Za-z0-9_-]*) echo "deck.sh: a profile is letters, digits, _ and - only" >&2; exit 1 ;;
esac

DECK_DIR=/mnt/us/streamdeckify
KO=/mnt/us/koreader
DECK_TMP=/var/tmp/streamdeckify
FBINK=/var/tmp/streamdeckify-fbink
FB_DUMP=/var/tmp/streamdeckify-fb.dump
# MEASURE: an FBInk build that can draw PNGs. KOReader's usually can't; the jailbreak's usually can.
FBINK_SOURCES="/var/local/kmc/bin/fbink /mnt/us/libkh/bin/fbink"

export DECK_DIR DECK_TMP FBINK KO_DIR="$KO"
export DECK_LOG="$DECK_DIR/deck.log"
export DISPLAY=:0
export LC_ALL=en_US.UTF-8

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') deck.sh${PROFILE:+[$PROFILE]}: $*" >> "$DECK_LOG"; }

CONFIG="$DECK_DIR/config${PROFILE:+-$PROFILE}"
if [ ! -f "$CONFIG" ]; then
    log "no $CONFIG: run deploy.sh on the computer"
    exit 1
fi
# DECK_NAME, DECK_TOKEN and, if you want them, DECK_URL, DECK_DISCOVERY, DECK_TOUCH and DECK_UDP_PORT
. "$CONFIG"
: "${DECK_NAME:=${PROFILE:-deck}}"
: "${DECK_UDP_PORT:=8788}"
: "${DECK_DISCOVERY:=1}"
export DECK_NAME DECK_URL DECK_TOKEN DECK_UDP_PORT DECK_DISCOVERY DECK_TOUCH

for p in $(pidof luajit 2>/dev/null); do
    if grep -q deck.lua "/proc/$p/cmdline" 2>/dev/null; then
        log "a deck is already running (pid $p)"
        exit 1
    fi
done

FBINK_SOURCE=""
for f in $FBINK_SOURCES; do
    if [ -x "$f" ]; then FBINK_SOURCE="$f"; break; fi
done
if [ -z "$FBINK_SOURCE" ]; then
    log "no FBInk that draws images in: $FBINK_SOURCES"
    exit 1
fi
mkdir -p "$DECK_TMP"
# /mnt/us is FAT, so binaries get copied out before they run, as koreader.sh does.
cp -f "$FBINK_SOURCE" "$FBINK" && chmod 755 "$FBINK"

AWESOME_STOPPED=no
XORG_STOPPED=no
PILLOW_DISABLED=no
UDP_RULE=no
TITLEBAR_GEOMETRY=""

restore() {
    trap - EXIT INT TERM HUP
    log "restoring the interface"
    if [ "$XORG_STOPPED" = yes ]; then
        killall -CONT Xorg
    fi
    if [ "$AWESOME_STOPPED" = yes ]; then
        killall -CONT awesome
    fi
    if [ "$PILLOW_DISABLED" = yes ]; then
        if [ -f "$FB_DUMP" ]; then
            cat "$FB_DUMP" > /dev/fb0
            rm -f "$FB_DUMP"
        fi
        lipc-set-prop com.lab126.pillow disableEnablePillow enable
        lipc-set-prop com.lab126.appmgrd start app://com.lab126.booklet.home
    fi
    if [ -n "$TITLEBAR_GEOMETRY" ]; then
        usleep 250000
        TRIES=0
        until [ "$("$KO/wmctrl" -l -G | grep ":titleBar_ID:" | awk '{print $2,$3,$4,$5,$6}' OFS=',')" = "$TITLEBAR_GEOMETRY" ]; do
            if [ $TRIES -gt 20 ]; then log "couldn't restore the title bar"; break; fi
            "$KO/wmctrl" -r ":titleBar_ID:" -e "$TITLEBAR_GEOMETRY"
            usleep 250000
            TRIES=$((TRIES + 1))
        done
    fi
    if [ "$UDP_RULE" = yes ]; then
        iptables -D INPUT -i wlan0 -p udp --sport "$DECK_UDP_PORT" -j ACCEPT 2>/dev/null
    fi
    # Always back to 0. Left at 1, the power button stops putting the Kindle to sleep.
    lipc-set-prop com.lab126.powerd preventScreenSaver 0
    "$FBINK" -q -f -s 2>/dev/null   # one flashing refresh to clear what's left
    rm -f "$FBINK"
    log "interface restored"
}
trap restore EXIT INT TERM HUP

log "starting deck '$DECK_NAME' (fixed URL: ${DECK_URL:-none, UDP discovery})"
# The Kindle's firewall drops the answers to the discovery broadcast: let only those in.
if [ "$DECK_DISCOVERY" != 0 ] && iptables -I INPUT -i wlan0 -p udp --sport "$DECK_UDP_PORT" -j ACCEPT 2>/dev/null; then
    UDP_RULE=yes
fi
# Stay awake while the deck is open. restore() sets it back to 0.
lipc-set-prop com.lab126.powerd preventScreenSaver 1
cat /dev/fb0 > "$FB_DUMP"
lipc-set-prop com.lab126.pillow disableEnablePillow disable
PILLOW_DISABLED=yes
TITLEBAR_GEOMETRY="$("$KO/wmctrl" -l -G | grep ":titleBar_ID:" | awk '{print $2,$3,$4,$5,$6}' OFS=',')"
if [ -n "$TITLEBAR_GEOMETRY" ]; then
    "$KO/wmctrl" -r ":titleBar_ID:" -e "${TITLEBAR_GEOMETRY%,*},1"
fi
killall -STOP awesome
AWESOME_STOPPED=yes
# With only awesome stopped, X clients still repaint parts of the screen over
# the deck, because the X server writes to the framebuffer. Stopping Xorg too
# prevents it. The lab126_gui watchdog only reacts when a job ends badly, not
# to SIGSTOP.
killall -STOP Xorg
XORG_STOPPED=yes

cd "$KO" || exit 1
./luajit "$DECK_DIR/deck.lua" >> "$DECK_LOG" 2>&1
RC=$?
log "deck.lua ended with code $RC"
exit $RC
