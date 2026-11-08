#!/usr/bin/env python3
"""Streamdeckify reference server for a Kindle deck.

Draws the whole panel as one grayscale image at the Kindle's exact resolution
from config/buttons.json, serves it to the Kindle and runs the action of the
button that was tapped. Works on macOS and Linux with Python 3.8 or newer and
Pillow, and nothing else.

HTTP on the configured port. Every route needs the X-Token header, except /health:
  GET  /health                          "ok"
  GET  /layout                          the version, then one "id x y w h type" line per button
  GET  /panel.png                       the whole panel
  GET  /tile/<id>?state=normal|pressed  one button; pressed is the same tile inverted
  POST /tap with form fields x and y    starts the action of the button there, answers its id or "-"

Discovery: a datagram "streamdeckify? <name>" to UDP discovery_port (8788) gets
"streamdeckify <name> <port>" back, so the Kindle finds this computer even
when its IP changes.

Safety: only the local network and this computer get an answer, every request
needs the random token in config/token, and a tap only says where the finger
was. The action comes from config/buttons.json, and its type from the fixed
list in ACTIONS.
"""
import glob
import hmac
import io
import ipaddress
import json
import logging
import os
import plistlib
import re
import secrets
import socket
import subprocess
import sys
import threading
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = os.path.join(ROOT, "config", "buttons.json")
TOKEN_FILE = os.path.join(ROOT, "config", "token")
LOG_FILE = os.path.join(ROOT, "logs", "server.log")
CACHE = os.path.join(ROOT, "cache")
SYMBOL_SOURCE = os.path.join(ROOT, "macos", "sf-symbol.swift")
KEYS_APP = os.path.join(CACHE, "Streamdeckify Keys.app")
KEYS_BUILD = os.path.join(ROOT, "macos", "build-keys.sh")

IS_MAC = sys.platform == "darwin"

# The fixed list of actions. The Kindle handles "refresh" and "exit" itself.
ACTIONS = ("app", "url", "key", "shortcut", "command", "media", "refresh", "exit")
KINDLE_ACTIONS = ("refresh", "exit")
# Button ids and the deck's name end up in file names and commands on the Kindle: plain words only.
WORD = re.compile(r"[A-Za-z0-9_-]{1,32}")

# Only these addresses get an answer: the local network and this computer.
LOCAL_NETWORKS = [ipaddress.ip_network(n) for n in (
    "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "169.254.0.0/16", "127.0.0.0/8",
    "fc00::/7", "fe80::/10", "::1/128",
)]

# Drawing, in pixels for a screen 758 pixels wide (the Paperwhite 2). Other screens scale it.
MARGIN, GAP, BORDER, RADIUS = 14, 14, 4, 18
LABEL_SIZE, LABEL_ONLY_SIZE, SMALLEST_SIZE = 38, 46, 16
FONTS = [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",                 # macOS
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",              # Debian, Ubuntu
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
    "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",                          # Arch
]
FALLBACK_FONTS = [  # for characters the main font lacks, like the ⌘ and ⌥ symbols
    "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/TTF/DejaVuSans.ttf",
]
APP_FOLDERS = ["/Applications", os.path.expanduser("~/Applications"), "/System/Applications",
               "/System/Applications/Utilities"]
MEDIA_PLAYERS = ("Spotify", "Music")  # macOS "media" buttons, in this order

# "key" buttons. Modifier: (name for the macOS helper app, xdotool name).
MODIFIERS = {
    "cmd": ("command", "super"), "command": ("command", "super"),
    "option": ("option", "alt"), "opt": ("option", "alt"), "alt": ("option", "alt"),
    "ctrl": ("control", "ctrl"), "control": ("control", "ctrl"),
    "shift": ("shift", "shift"),
}
MODIFIER_CODES = {"command": 55, "option": 58, "control": 59, "shift": 56}
# Key: (macOS virtual key code, xdotool name).
KEYS = {
    "space": (49, "space"), "return": (36, "Return"), "enter": (36, "Return"), "tab": (48, "Tab"),
    "escape": (53, "Escape"), "esc": (53, "Escape"), "delete": (51, "BackSpace"),
    "backspace": (51, "BackSpace"), "forwarddelete": (117, "Delete"),
    "up": (126, "Up"), "down": (125, "Down"), "left": (123, "Left"), "right": (124, "Right"),
    "home": (115, "Home"), "end": (119, "End"), "pageup": (116, "Prior"), "pagedown": (121, "Next"),
    "f1": (122, "F1"), "f2": (120, "F2"), "f3": (99, "F3"), "f4": (118, "F4"), "f5": (96, "F5"),
    "f6": (97, "F6"), "f7": (98, "F7"), "f8": (100, "F8"), "f9": (101, "F9"), "f10": (109, "F10"),
    "f11": (103, "F11"), "f12": (111, "F12"),
}
# Letters and digits. macOS key codes follow the key's place on the keyboard, not its letter.
KEYS.update({k: (code, k) for k, code in {
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11,
    "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "o": 31, "u": 32, "i": 34, "p": 35,
    "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
    "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "9": 25, "7": 26, "8": 28, "0": 29,
}.items()})

os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[logging.FileHandler(LOG_FILE), logging.StreamHandler(sys.stdout)],
)
log = logging.getLogger("streamdeckify")


def first_existing(paths):
    return next((p for p in paths if os.path.exists(p)), None)


def is_local(address):
    """True for an address on the local network or on this computer."""
    try:
        ip = ipaddress.ip_address(address.split("%")[0])
    except ValueError:
        return False
    if ip.version == 6 and ip.ipv4_mapped:
        ip = ip.ipv4_mapped
    return any(ip in net for net in LOCAL_NETWORKS)


def read_token():
    """The shared secret. Made at random on the first start, readable only by you."""
    if not os.path.exists(TOKEN_FILE):
        fd = os.open(TOKEN_FILE, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "w") as f:
            f.write(secrets.token_hex(16) + "\n")
        log.info("new random token in %s", TOKEN_FILE)
    os.chmod(TOKEN_FILE, 0o600)
    with open(TOKEN_FILE) as f:
        token = f.read().strip()
    if not re.fullmatch(r"[A-Za-z0-9]{16,}", token):
        sys.exit("%s must hold a token of at least 16 letters or digits" % TOKEN_FILE)
    return token


def key_parts(value):
    """"cmd+shift+3" -> ([("command", "super"), ("shift", "shift")], "3"). Raises if it can't press it."""
    if not isinstance(value, str) or not value.strip():
        raise ValueError("a key is a combination like cmd+shift+3")
    parts = [p for p in re.split(r"[+\s]+", value.strip()) if p]
    mods = [MODIFIERS[p.lower()] for p in parts if p.lower() in MODIFIERS]
    keys = [p for p in parts if p.lower() not in MODIFIERS]
    if len(keys) > 1:
        raise ValueError("one key at most besides the modifiers: %r" % value)
    if not keys and len(mods) != 1:
        raise ValueError("a key, or a single modifier on its own: %r" % value)
    key = keys[0] if keys else None
    # On Linux any X key name (like XF86AudioMute) goes to xdotool as it is.
    if key is not None and key.lower() not in KEYS and (IS_MAC or not re.fullmatch(r"[A-Za-z0-9_]+", key)):
        raise ValueError("unknown key %r" % key)
    return mods, key


def check_button(b, seen):
    """Raises ValueError unless the button is one this server knows how to run."""
    if not isinstance(b, dict):
        raise ValueError("each cell is a button or null, not %r" % (b,))
    bid = b.get("id")
    if not isinstance(bid, str) or not WORD.fullmatch(bid):
        raise ValueError("button id %r: use 1 to 32 letters, digits, _ or -" % (bid,))
    if bid in seen:
        raise ValueError("two buttons have the id %r" % bid)
    seen.add(bid)
    kind, value = b.get("type"), b.get("value")
    if kind not in ACTIONS:
        raise ValueError("button %s: type %r is not one of %s" % (bid, kind, ", ".join(ACTIONS)))
    if kind == "command":
        if not (isinstance(value, list) and value and all(isinstance(a, str) and a for a in value)):
            raise ValueError("button %s: a command is a list of arguments, never a shell string" % bid)
    elif kind in ("app", "url", "shortcut"):
        if not isinstance(value, str) or not value.strip() or value.startswith("-"):
            raise ValueError("button %s: %s needs a value" % (bid, kind))
    elif kind == "key":
        key_parts(value)
    if not isinstance(b.get("label", bid), str):
        raise ValueError("button %s: the label is text" % bid)
    if not isinstance(b.get("icon", ""), str):
        raise ValueError("button %s: the icon is text" % bid)


# --- icons -----------------------------------------------------------------------------------

def find_app(name):
    """The .app bundle of a macOS app by its name, as `open -a` finds it, or None."""
    return first_existing(os.path.join(folder, name + ".app") for folder in APP_FOLDERS)


def app_icon_path(name):
    """The .icns file of a macOS app."""
    app = find_app(name)
    if not app:
        r = subprocess.run(["mdfind", "kMDItemFSName == '%s.app'" % name.replace("'", "")],
                           capture_output=True, text=True, timeout=15)
        app = next((line for line in r.stdout.splitlines() if line.endswith(".app")), None)
        if not app:
            raise FileNotFoundError("no app called %r" % name)
    resources = os.path.join(app, "Contents", "Resources")
    candidates = []
    with open(os.path.join(app, "Contents", "Info.plist"), "rb") as f:
        icon_file = plistlib.load(f).get("CFBundleIconFile")
    if icon_file:
        candidates.append(os.path.join(resources, icon_file if icon_file.endswith(".icns") else icon_file + ".icns"))
    candidates += sorted(glob.glob(os.path.join(resources, "*.icns")))
    path = first_existing(candidates)
    if not path:
        raise FileNotFoundError("the app %r has no .icns icon" % name)
    return path


def symbol_png(name):
    """An SF Symbol as a PNG, drawn once by macos/sf-symbol.swift and kept in cache/."""
    if not IS_MAC:
        raise RuntimeError("SF Symbols only exist on macOS")
    if not re.fullmatch(r"[a-z0-9.]+", name):
        raise ValueError("odd symbol name %r" % name)
    os.makedirs(CACHE, exist_ok=True)
    out = os.path.join(CACHE, "symbol-%s.png" % name)
    if not os.path.exists(out):
        # Compiled once, because running the .swift file as a script takes seconds per icon.
        tool = os.path.join(CACHE, "sf-symbol")
        if not os.path.exists(tool) or os.path.getmtime(tool) < os.path.getmtime(SYMBOL_SOURCE):
            r = subprocess.run(["xcrun", "swiftc", "-O", SYMBOL_SOURCE, "-o", tool],
                               capture_output=True, text=True, timeout=300)
            if r.returncode != 0:
                raise RuntimeError("can't compile sf-symbol.swift: " + (r.stderr or r.stdout).strip()[-300:])
        r = subprocess.run([tool, name, out, "256"], capture_output=True, text=True, timeout=60)
        if r.returncode != 0:
            raise RuntimeError((r.stderr or r.stdout).strip()[-300:])
    return out


def load_icon(spec):
    if spec.startswith("app:"):
        path = app_icon_path(spec[4:].strip())
    elif spec.startswith("symbol:"):
        path = symbol_png(spec[7:].strip())
    else:
        path = spec if os.path.isabs(spec) else os.path.join(ROOT, "config", spec)
    img = Image.open(path)
    img.load()
    return img


def fit_icon(img, box):
    """Trims the transparent margin, fits the icon in the box and turns it gray on white."""
    img = img.convert("RGBA")
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    img.thumbnail(box, Image.LANCZOS)
    background = Image.new("RGBA", img.size, (255, 255, 255, 255))
    background.alpha_composite(img)
    return background.convert("L")


# --- actions ---------------------------------------------------------------------------------

def press_key_mac(value):
    """Presses the combination with the helper app "Streamdeckify Keys" (macos/keys/).

    It goes through `open`, so macOS sees an app of its own and the Accessibility permission
    belongs to "Streamdeckify Keys". Given to the Python that runs this server, it didn't stick.
    Returns (ok, message).
    """
    mods, key = key_parts(value)
    names = [m[0] for m in mods]
    if key is None:
        code, names = MODIFIER_CODES[names[0]], []
    else:
        code = KEYS[key.lower()][0]
    if not os.path.exists(os.path.join(KEYS_APP, "Contents", "MacOS", "keys")):
        log.info("building the key helper app; the first key press asks for Accessibility")
        r = subprocess.run(["sh", KEYS_BUILD], capture_output=True, text=True, timeout=300)
        if r.returncode != 0:
            return False, "can't build the key helper: " + (r.stderr or r.stdout).strip()[-300:]
    result = os.path.join(CACHE, "keys-result-%d" % threading.get_ident())
    if os.path.exists(result):
        os.remove(result)
    r = subprocess.run(["open", "-W", "-n", "-a", KEYS_APP, "--args", str(code), ",".join(names), result],
                       capture_output=True, text=True, timeout=30)
    if r.returncode != 0:
        return False, "open failed: " + (r.stderr or r.stdout).strip()[-300:]
    try:
        with open(result) as f:
            text = f.read().strip()
        os.remove(result)
    except OSError:
        return False, "the key helper left no result"
    return text == "ok", text


def xdotool_keys(value):
    mods, key = key_parts(value)
    parts = [m[1] for m in mods]
    if key is not None:
        parts.append(KEYS[key.lower()][1] if key.lower() in KEYS else key)
    return "+".join(parts)


def media_applescript():
    """Play or pause, without starting a player by mistake: pause the one that plays; if none
    plays, resume the one that is open; if none is open, open the first one. Only installed
    players go in, because AppleScript can't compile a script for an app that isn't there.
    The first time, macOS asks to let the server control each player (Automation)."""
    players = [p for p in MEDIA_PLAYERS if find_app(p)]
    if not players:
        raise RuntimeError("none of %s is installed" % ", ".join(MEDIA_PLAYERS))
    lines = []
    for p in players:
        lines += ['if application "%s" is running then' % p,
                  '    tell application "%s"' % p,
                  '        if player state is playing then',
                  '            pause',
                  '            return "%s paused"' % p,
                  '        end if',
                  '    end tell',
                  'end if']
    for p in players:
        lines += ['if application "%s" is running then' % p,
                  '    tell application "%s" to play' % p,
                  '    return "%s playing"' % p,
                  'end if']
    lines += ['tell application "%s" to activate' % players[0],
              'return "nothing was open, opening %s"' % players[0]]
    return "\n".join(lines)


def report(b, ok, start, detail=""):
    ms = int((time.time() - start) * 1000)
    if ok:
        log.info("action %s ok in %d ms%s", b["id"], ms, ": " + detail[:200] if detail else "")
    else:
        log.error("action %s failed in %d ms: %s", b["id"], ms, detail[:300])


def run_action(b):
    """Runs the button's action on this computer, in a thread of its own."""
    kind, value, start = b["type"], b.get("value"), time.time()
    try:
        if kind == "key" and IS_MAC:
            ok, message = press_key_mac(value)
            return report(b, ok, start, "" if ok else message)
        if kind == "app":
            cmd = ["open", "-a", value] if IS_MAC else ["gtk-launch", value]
        elif kind == "url":
            cmd = ["open" if IS_MAC else "xdg-open", value]
        elif kind == "shortcut":
            if not IS_MAC:
                return report(b, False, start, "Shortcuts only exist on macOS")
            cmd = ["shortcuts", "run", value]
        elif kind == "command":
            cmd = list(value)  # an argument list, never through a shell
        elif kind == "key":
            cmd = ["xdotool", "key", xdotool_keys(value)]
        elif kind == "media":
            cmd = ["osascript", "-e", media_applescript()] if IS_MAC else ["playerctl", "play-pause"]
        else:
            return  # refresh and exit: the Kindle handles them
        # 60 s, because the first media or shortcut tap can wait on a macOS permission prompt.
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        if r.returncode == 0:
            report(b, True, start, r.stdout.strip() if kind == "media" else "")
        else:
            report(b, False, start, "exit code %d: %s" % (r.returncode, (r.stderr or r.stdout).strip()))
    except Exception as e:  # noqa: BLE001  A failed action must never take the server down.
        report(b, False, start, str(e))


# --- the panel -------------------------------------------------------------------------------

class Panel:
    """The config, the grid and the drawing. Reloads itself when buttons.json changes."""

    def __init__(self):
        self.lock = threading.Lock()
        self.font = first_existing(FONTS)
        self.fallback_font = first_existing(FALLBACK_FONTS)
        if not self.font:
            log.warning("no TrueType font found, using Pillow's own (on Linux, install fonts-dejavu-core)")
        self.fonts = {}
        self.glyphs = {}
        self.load()

    def load(self):
        """Reads and checks buttons.json. Raises on any mistake, before touching the current config."""
        mtime = os.path.getmtime(CONFIG)
        with open(CONFIG, encoding="utf-8") as f:
            cfg = json.load(f)
        width, height = int(cfg["screen"]["width"]), int(cfg["screen"]["height"])
        cols, rows = int(cfg.get("columns", 3)), int(cfg.get("rows", 4))
        cells = cfg.get("buttons")
        if not isinstance(cells, list) or cols < 1 or rows < 1 or len(cells) > cols * rows:
            raise ValueError("buttons must be a list of at most columns x rows cells")
        scale = min(width, height) / 758.0
        margin, gap = round(MARGIN * scale), round(GAP * scale)
        cell_w = (width - 2 * margin - (cols - 1) * gap) // cols
        cell_h = (height - 2 * margin - (rows - 1) * gap) // rows
        if cell_w < 40 or cell_h < 40:
            raise ValueError("cells of %dx%d pixels are too small to tap" % (cell_w, cell_h))
        buttons, seen = [], set()
        for i, b in enumerate(cells):
            if b is None:
                continue  # an empty cell
            check_button(b, seen)
            col, row = i % cols, i // cols
            buttons.append(dict(b, x=margin + col * (cell_w + gap), y=margin + row * (cell_h + gap),
                                w=cell_w, h=cell_h))
        self.cfg, self.scale, self.size = cfg, scale, (width, height)
        self.buttons, self.mtime, self.version = buttons, mtime, str(int(mtime * 1000))
        self.cache, self.icons = {}, {}
        log.info("config loaded: %d buttons, version %s", len(buttons), self.version)

    def refresh(self):
        """Reloads buttons.json if it changed. A broken file keeps the last good config."""
        with self.lock:
            try:
                mtime = os.path.getmtime(CONFIG)
            except OSError as e:
                log.error("can't read config/buttons.json: %s", e)
                return
            if mtime == self.mtime:
                return
            try:
                self.load()
            except (OSError, ValueError, KeyError, TypeError) as e:
                self.mtime = mtime  # don't try again until the file changes
                log.error("config/buttons.json: %s. Keeping the last good config.", e)

    def layout(self):
        self.refresh()
        lines = [self.version] + ["%s %d %d %d %d %s" % (b["id"], b["x"], b["y"], b["w"], b["h"], b["type"])
                                  for b in self.buttons]
        return "\n".join(lines) + "\n"

    def button_at(self, x, y):
        self.refresh()
        return next((b for b in self.buttons
                     if b["x"] <= x < b["x"] + b["w"] and b["y"] <= y < b["y"] + b["h"]), None)

    def button(self, bid):
        self.refresh()
        return next((b for b in self.buttons if b["id"] == bid), None)

    # --- drawing, always with the lock held ---

    def _font(self, size, fallback=False):
        key = (size, fallback)
        if key not in self.fonts:
            path = self.fallback_font if fallback else self.font
            if path:
                self.fonts[key] = ImageFont.truetype(path, size)
            else:
                try:
                    self.fonts[key] = ImageFont.load_default(size=size)
                except TypeError:  # Pillow older than 10.1
                    self.fonts[key] = ImageFont.load_default()
        return self.fonts[key]

    def _has_glyph(self, ch):
        """False when the main font lacks the character, so the fallback font draws it."""
        if ch not in self.glyphs:
            ok = True
            if self.font and self.fallback_font and not ch.isspace():
                font = self._font(40)

                def mask(c):
                    im = Image.new("L", (64, 64), 0)
                    ImageDraw.Draw(im).text((4, 4), c, font=font, fill=255)
                    return im.tobytes()

                ok = mask(ch) != mask("￿")  # the same shape as a character no font has
            self.glyphs[ch] = ok
        return self.glyphs[ch]

    def _runs(self, line, size):
        """Splits a line into runs of (text, font), by which font has each character."""
        runs = []
        for ch in line:
            fallback = not self._has_glyph(ch)
            if runs and runs[-1][1] == fallback:
                runs[-1][0] += ch
            else:
                runs.append([ch, fallback])
        return [(text, self._font(size, fallback)) for text, fallback in runs]

    def _measure(self, lines, size):
        widths = [sum(font.getlength(text) for text, font in self._runs(line, size)) for line in lines]
        return max(widths), size * 1.2 * len(lines)

    def _text(self, draw, cx, cy, text, max_w, max_h, max_size):
        """Draws centered text, as big as fits, down to SMALLEST_SIZE."""
        lines = text.split("\n")
        size, smallest = max_size, round(SMALLEST_SIZE * self.scale)
        while size > smallest:
            w, h = self._measure(lines, size)
            if w <= max_w and h <= max_h:
                break
            size -= 2
        line_h = size * 1.2
        y = cy - line_h * len(lines) / 2
        for line in lines:
            runs = self._runs(line, size)
            x = cx - sum(font.getlength(t) for t, font in runs) / 2
            for t, font in runs:
                draw.text((x, y + size * 0.98), t, font=font, fill=0, anchor="ls")
                x += font.getlength(t)
            y += line_h

    def _icon(self, b, box):
        spec = b.get("icon")
        if spec is None and b["type"] == "app" and IS_MAC:
            spec = "app:" + b["value"]
        if not spec:
            return None
        key = (spec, box)
        if key not in self.icons:
            img = None
            try:
                img = fit_icon(load_icon(spec), box)
            except Exception as e:  # noqa: BLE001  A missing icon only costs the picture.
                log.warning("icon %r of button %s: %s", spec, b["id"], e)
            self.icons[key] = img
        return self.icons[key]

    def _tile(self, b):
        """A button in its normal state: a grayscale image the size of its cell."""
        key = ("tile", b["id"])
        if key not in self.cache:
            s, w, h = self.scale, b["w"], b["h"]
            img = Image.new("L", (w, h), 255)
            draw = ImageDraw.Draw(img)
            draw.rounded_rectangle([0, 0, w - 1, h - 1], radius=round(RADIUS * s), fill=255, outline=0,
                                   width=max(1, round(BORDER * s)))
            label = b.get("label", b["id"])
            icon = self._icon(b, (int(w * 0.50), int(h * 0.44)))
            if icon:
                img.paste(icon, ((w - icon.width) // 2, int(h * 0.36) - icon.height // 2))
                self._text(draw, w / 2, h * 0.78, label, w - 24 * s, h * 0.34, round(LABEL_SIZE * s))
            else:
                self._text(draw, w / 2, h / 2, label, w - 28 * s, h - 28 * s, round(LABEL_ONLY_SIZE * s))
            self.cache[key] = img
        return self.cache[key]

    def panel_png(self):
        self.refresh()
        with self.lock:
            if "panel" not in self.cache:
                img = Image.new("L", self.size, 255)
                for b in self.buttons:
                    img.paste(self._tile(b), (b["x"], b["y"]))
                self.cache["panel"] = self._png(img)
            return self.cache["panel"]

    def tile_png(self, b, pressed):
        with self.lock:
            key = ("png", b["id"], pressed)
            if key not in self.cache:
                img = self._tile(b)
                self.cache[key] = self._png(ImageOps.invert(img) if pressed else img)
            return self.cache[key]

    @staticmethod
    def _png(img):
        buf = io.BytesIO()
        img.save(buf, "PNG", optimize=True)
        return buf.getvalue()


# --- network ---------------------------------------------------------------------------------

def answer_discovery(name, http_port, udp_port):
    """Answers the Kindles on the local network that look for this computer by its name."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        s.bind(("0.0.0.0", udp_port))  # every interface, or broadcasts don't arrive
    except OSError as e:
        log.error("discovery can't listen on UDP %d: %s", udp_port, e)
        return
    log.info("discovery for '%s' on UDP %d", name, udp_port)
    while True:
        try:
            data, sender = s.recvfrom(512)
        except OSError:
            time.sleep(1)
            continue
        if not is_local(sender[0]):
            continue
        parts = data.decode("utf-8", "replace").split()
        if parts and parts[0] == "streamdeckify?" and (len(parts) == 1 or parts[1] == name):
            s.sendto(("streamdeckify %s %d\n" % (name, http_port)).encode(), sender)
            log.info("discovery: answered %s", sender[0])


class Handler(BaseHTTPRequestHandler):
    server_version = "streamdeckify"
    sys_version = ""
    timeout = 10
    panel = None
    token = ""

    def log_message(self, fmt, *args):  # taps and actions have their own log lines
        pass

    def _reply(self, code, body, content_type="text/plain; charset=utf-8"):
        if isinstance(body, str):
            body = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _authorized(self):
        sent = self.headers.get("X-Token") or ""
        return hmac.compare_digest(sent.encode("utf-8"), self.token.encode("utf-8"))

    def do_GET(self):
        url = urllib.parse.urlparse(self.path)
        if url.path == "/health":
            return self._reply(200, "ok\n")
        if not self._authorized():
            return self._reply(403, "token\n")
        if url.path == "/layout":
            return self._reply(200, self.panel.layout())
        if url.path == "/panel.png":
            return self._reply(200, self.panel.panel_png(), "image/png")
        if url.path.startswith("/tile/"):
            b = self.panel.button(url.path[len("/tile/"):])
            if not b:
                return self._reply(404, "no such button\n")
            state = urllib.parse.parse_qs(url.query).get("state", ["normal"])[0]
            return self._reply(200, self.panel.tile_png(b, state == "pressed"), "image/png")
        return self._reply(404, "not found\n")

    def do_POST(self):
        if not self._authorized():
            return self._reply(403, "token\n")
        if urllib.parse.urlparse(self.path).path != "/tap":
            return self._reply(404, "not found\n")
        try:
            length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            length = -1
        if not 0 <= length <= 256:
            return self._reply(400, "body\n")
        form = urllib.parse.parse_qs(self.rfile.read(length).decode("utf-8", "replace"))
        try:
            x, y = int(form["x"][0]), int(form["y"][0])
        except (KeyError, ValueError):
            return self._reply(400, "x and y\n")
        b = self.panel.button_at(x, y)
        if not b:
            log.info("tap %d,%d: no button there", x, y)
            return self._reply(200, "-\n")
        log.info("tap %d,%d -> %s (%s)", x, y, b["id"], b["type"])
        if b["type"] not in KINDLE_ACTIONS:
            threading.Thread(target=run_action, args=(b,), daemon=True).start()
        return self._reply(200, b["id"] + "\n")


class Server(ThreadingHTTPServer):
    daemon_threads = True

    def verify_request(self, request, client_address):
        if is_local(client_address[0]):
            return True
        log.warning("refused %s: not on the local network", client_address[0])
        return False


def main():
    try:
        panel = Panel()
    except FileNotFoundError:
        sys.exit("No config/buttons.json yet. Copy config/buttons.macos.json or config/buttons.linux.json "
                 "to it, then set the screen size you measured.")
    except (OSError, ValueError, KeyError, TypeError) as e:
        sys.exit("config/buttons.json: %s" % e)
    cfg = panel.cfg
    name = str(cfg.get("name", "deck"))
    if not WORD.fullmatch(name):
        sys.exit("config/buttons.json: the name is 1 to 32 letters, digits, _ or -")
    listen = str(cfg.get("listen", "0.0.0.0"))
    port = int(cfg.get("port", 8787))
    udp_port = cfg.get("discovery_port", 8788)
    Handler.panel, Handler.token = panel, read_token()
    if udp_port:
        threading.Thread(target=answer_discovery, args=(name, port, int(udp_port)), daemon=True).start()
    server = Server((listen, port), Handler)
    log.info("streamdeckify '%s' on %s:%d (%s), answering the local network only",
             name, listen, port, "macOS" if IS_MAC else "Linux")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
