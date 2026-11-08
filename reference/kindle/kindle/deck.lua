-- Streamdeckify reference client for a jailbroken Kindle, run with KOReader's LuaJIT.
--
-- It finds the computer (a fixed URL, the last one that worked, or UDP
-- discovery), fetches the layout and the panel, draws them with FBInk, takes
-- the touchscreen for itself with EVIOCGRAB and, on each tap, inverts the
-- button at once and tells the computer where the tap was. The computer
-- decides what to run. deck.sh starts this with Amazon's interface paused and
-- puts it back afterwards.
--
-- Settings come from the environment, set by deck.sh and its config file:
--   DECK_NAME, DECK_TOKEN, DECK_URL (optional), DECK_DISCOVERY (0 turns it off),
--   DECK_UDP_PORT, DECK_TOUCH, DECK_DIR, DECK_TMP, DECK_LOG, FBINK, KO_DIR.
--
-- What changes from one Kindle to another is marked MEASURE.

local ffi = require("ffi")

ffi.cdef[[
int open(const char *pathname, int flags);
int ioctl(int fd, unsigned long request, void *arg);
int read(int fd, void *buf, size_t count);
int close(int fd);
typedef struct { int fd; short events; short revents; } pollfd;
int poll(pollfd *fds, unsigned long nfds, int timeout);
typedef struct { long tv_sec; long tv_usec; } timeval;
int gettimeofday(timeval *tv, void *tz);
typedef struct { timeval time; uint16_t type; uint16_t code; int32_t value; } input_event;
]]

local KO = os.getenv("KO_DIR") or "/mnt/us/koreader"
package.path = KO .. "/common/?.lua;" .. KO .. "/?.lua;" .. package.path
package.cpath = KO .. "/common/?.so;" .. package.cpath
local has_socket, socket = pcall(require, "socket")

local NAME      = os.getenv("DECK_NAME") or "deck"
local URL       = os.getenv("DECK_URL"); if URL == "" then URL = nil end
local TOKEN     = os.getenv("DECK_TOKEN") or ""
local DISCOVERY = os.getenv("DECK_DISCOVERY") ~= "0"
local UDP_PORT  = tonumber(os.getenv("DECK_UDP_PORT") or "8788")
local DIR       = os.getenv("DECK_DIR") or "/mnt/us/streamdeckify"
local TMP       = os.getenv("DECK_TMP") or "/var/tmp/streamdeckify"
local FBINK     = os.getenv("FBINK") or "/var/tmp/streamdeckify-fbink"
local LOG       = os.getenv("DECK_LOG") or (DIR .. "/deck.log")
-- MEASURE: the touchscreen's event device, from /proc/bus/input/devices.
local TOUCH     = os.getenv("DECK_TOUCH") or "/dev/input/event1"

local EVIOCGRAB = 0x40044590
local EV_SYN, EV_ABS = 0, 3
local ABS_MT_SLOT, ABS_MT_POSITION_X, ABS_MT_POSITION_Y, ABS_MT_TRACKING_ID = 0x2f, 0x35, 0x36, 0x39
local TAPS_BEFORE_FULL_REFRESH = 15   -- a flashing refresh now and then clears the ghosting
local LAYOUT_CHECK_SECONDS = 60
local DEBOUNCE_SECONDS = 0.5          -- some touch controllers split one tap into two contacts
local MAX_MOVE = 40                   -- pixels: a finger that moves more is a swipe, not a tap
local LAST_URL = DIR .. "/last-url-" .. NAME

-- MEASURE: the Paperwhite 2 reports touches 1:1 in screen pixels. If your
-- Kindle's axes are swapped, mirrored or scaled, convert them here.
local function to_screen(x, y)
  return x, y
end

local function now()
  local tv = ffi.new("timeval")
  ffi.C.gettimeofday(tv, nil)
  return tonumber(tv.tv_sec) + tonumber(tv.tv_usec) / 1e6
end

local logf = io.open(LOG, "a")
local function log(fmt, ...)
  local line = os.date("%Y-%m-%d %H:%M:%S ") .. string.format(fmt, ...)
  if logf then logf:write(line, "\n"); logf:flush() else print(line) end
end

local function sh(cmd)
  local ok = os.execute(cmd)
  return ok == 0 or ok == true
end

local function fbink(args)
  return sh(string.format("%s -q %s >/dev/null 2>&1", FBINK, args))
end

-- Single quotes for the shell, with any quote inside escaped.
local function quote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function message(text, row)
  fbink(string.format("-m -y %d -S 2 %s", row or 20, quote(text)))
end

-- These values go into shell commands, so check them before using them.
if not NAME:match("^[%w_%-]+$") then
  log("DECK_NAME must be letters, digits, _ or -")
  os.exit(4)
end
if not TOKEN:match("^%w+$") then
  log("no token in the config, run deploy.sh on the computer")
  message("No token. Run deploy.sh on the computer.", 20)
  sh("sleep 3")
  os.exit(4)
end
if URL and not URL:match("^http://[%w%.%-]+:%d+$") then
  log("DECK_URL must look like http://192.168.1.x:8787, got %s", URL)
  os.exit(4)
end

local CURL = "curl -sf --connect-timeout 3 --max-time 6 -H 'X-Token: " .. TOKEN .. "'"

local function download(path, dest)
  return sh(string.format("%s -o %s '%s%s' && [ -s %s ] || { rm -f %s; false; }", CURL, dest, URL, path, dest, dest))
end

local function get(path)
  local p = io.popen(string.format("%s '%s%s' 2>/dev/null", CURL, URL, path))
  if not p then return nil end
  local out = p:read("*a")
  p:close()
  if out == nil or out == "" then return nil end
  return out
end

-- Finding the computer ----------------------------------------------------------

local function answers(url)
  local p = io.popen(string.format("curl -s --connect-timeout 2 --max-time 3 '%s/health' 2>/dev/null", url))
  if not p then return false end
  local s = p:read("*a") or ""
  p:close()
  return s:match("^ok") ~= nil
end

-- The Wi-Fi's directed broadcast address, like 192.168.1.255. The limited
-- broadcast, 255.255.255.255, often never reaches the computer.
local function broadcast_addresses()
  local list = {}
  local p = io.popen("ifconfig wlan0 2>/dev/null")
  if p then
    local s = p:read("*a") or ""
    p:close()
    local b = s:match("Bcast:(%d+%.%d+%.%d+%.%d+)")
    if b then list[#list + 1] = b end
  end
  list[#list + 1] = "255.255.255.255"
  return list
end

local function discover()
  if not DISCOVERY then return nil end
  if not has_socket then log("no luasocket, can't look for the computer") return nil end
  local u = socket.udp4 and socket.udp4() or socket.udp()
  if not u then return nil end
  u:setsockname("*", 0)
  local ok, err = u:setoption("broadcast", true)
  if not ok then log("can't turn on broadcast: %s", tostring(err)) end
  u:settimeout(1)
  local targets = broadcast_addresses()
  for attempt = 1, 2 do
    for _, target in ipairs(targets) do
      u:sendto("streamdeckify? " .. NAME, target, UDP_PORT)
    end
    local deadline = now() + 1.5
    while now() < deadline do
      local data, ip = u:receivefrom()
      if not data then break end
      local name, port = data:match("^streamdeckify (%S+) (%d+)")
      if name == NAME and ip:match("^%d+%.%d+%.%d+%.%d+$") then
        u:close()
        log("found '%s' at %s:%s (attempt %d)", name, ip, port, attempt)
        return string.format("http://%s:%s", ip, port)
      end
    end
  end
  u:close()
  return nil
end

local function find_computer()
  -- 1) the fixed URL, 2) the last one that worked, 3) UDP discovery
  if URL and answers(URL) then return URL end
  local f = io.open(LAST_URL, "r")
  if f then
    local u = f:read("*l"); f:close()
    if u and u ~= URL and u:match("^http://[%d%.]+:%d+$") and answers(u) then return u end
  end
  local u = discover()
  if u then
    local g = io.open(LAST_URL, "w")
    if g then g:write(u, "\n"); g:close() end
    return u
  end
  return nil
end

-- The layout: the version on the first line, then "id x y w h type" per button --

local function load_layout()
  local text = get("/layout")
  if not text then return nil end
  local buttons, version = {}, nil
  for line in text:gmatch("[^\n]+") do
    if not version then
      version = line
    else
      -- Ids and types end up in file names and shell commands: plain words only.
      local id, x, y, w, h, kind = line:match("^([%w_%-]+) (%d+) (%d+) (%d+) (%d+) ([%w_%-]+)$")
      if id then
        buttons[#buttons + 1] = { id = id, x = tonumber(x), y = tonumber(y), w = tonumber(w), h = tonumber(h), kind = kind }
      else
        log("layout line ignored: %s", line)
      end
    end
  end
  if not version or #buttons == 0 then return nil end
  return { version = version, buttons = buttons }
end

local function tile(b, state)
  local path = string.format("%s/%s-%s.png", TMP, b.id, state)
  local f = io.open(path, "rb")
  if f then f:close() return path end
  if download(string.format("/tile/%s?state=%s", b.id, state), path) then return path end
  return nil
end

local function draw_tile(b, state)
  local path = tile(b, state)
  if path then fbink(string.format("-g file=%s,x=%d,y=%d -W DU", path, b.x, b.y)) end
end

local function draw_panel(flash)
  local path = TMP .. "/panel.png"
  if not download("/panel.png", path) then log("can't download panel.png") return false end
  if not fbink(string.format("%s -g file=%s,x=0,y=0", flash and "-c -f" or "", path)) then
    log("FBInk couldn't draw the panel")
    return false
  end
  return true
end

local function preload(layout)
  for _, b in ipairs(layout.buttons) do
    tile(b, "pressed"); tile(b, "normal")
  end
end

local function button_at(layout, x, y)
  for _, b in ipairs(layout.buttons) do
    if x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h then return b end
  end
  return nil
end

-- Start: the computer, the layout and the panel, with a few tries ---------------

sh("mkdir -p " .. TMP .. " && rm -f " .. TMP .. "/*.png")
local layout
for attempt = 1, 6 do
  local u = find_computer()
  if u then
    URL = u
    layout = load_layout()
    if layout and draw_panel(true) then break end
    layout = nil
  end
  if u then
    -- It answers /health but sends no panel: most often a token that doesn't match.
    message(string.format("No panel from %s. Check the token and deck.log. Try %d of 6", u:gsub("^http://", ""), attempt), 20)
    log("no panel from %s for '%s', try %d", u, NAME, attempt)
  else
    message(string.format("Can't find %s on the Wi-Fi. Try %d of 6", NAME, attempt), 20)
    log("computer not found for '%s', try %d", NAME, attempt)
  end
  sh("sleep 3")
end
if not layout then
  message(string.format("Can't reach the computer for %s. Leaving.", NAME), 24)
  sh("sleep 3")
  os.exit(2)
end
log("deck '%s' at %s, version %s with %d buttons", NAME, URL, layout.version, #layout.buttons)
preload(layout)

-- The touchscreen, for us alone ---------------------------------------------------

local fd = ffi.C.open(TOUCH, 0)
if fd < 0 then log("can't open %s", TOUCH) os.exit(3) end
if ffi.C.ioctl(fd, EVIOCGRAB, ffi.cast("void*", 1)) ~= 0 then
  log("EVIOCGRAB failed (errno %d), going on without exclusive access", ffi.errno())
end

local pfd = ffi.new("pollfd[1]")
pfd[0].fd = fd
pfd[0].events = 1 -- POLLIN
local MAX_EVENTS = 64
local EVENT_SIZE = ffi.sizeof("input_event") -- 16 bytes with KOReader's 32-bit LuaJIT
local events = ffi.new("input_event[?]", MAX_EVENTS)

-- Drop the touches that piled up while loading.
while ffi.C.poll(pfd, 1, 0) > 0 and ffi.C.read(fd, events, EVENT_SIZE * MAX_EVENTS) > 0 do end

local slot, fingers, taps, last_check, quit = 0, {}, 0, now(), false
local last_id, last_t = nil, 0

local function on_tap(x, y)
  local t0 = now()
  local b = button_at(layout, x, y)
  if not b then log("tap %d,%d outside the buttons", x, y) return end
  if b.id == last_id and t0 - last_t < DEBOUNCE_SECONDS then
    log("tap %d,%d -> %s ignored (bounce, %d ms)", x, y, b.id, (t0 - last_t) * 1000)
    return
  end
  last_id, last_t = b.id, t0
  draw_tile(b, "pressed")
  local t_drawn = now()
  if b.kind == "exit" then
    log("tap %d,%d -> exit", x, y)
    quit = true
    return
  elseif b.kind == "refresh" then
    draw_panel(true)
    log("tap %d,%d -> refresh", x, y)
    return
  end
  local answer
  local p = io.popen(string.format("%s -X POST --data 'x=%d&y=%d' '%s/tap' 2>/dev/null", CURL, x, y, URL))
  if p then
    answer = p:read("*a")
    p:close()
    if answer == "" then answer = nil end
  end
  local t_computer = now()
  draw_tile(b, "normal")
  taps = taps + 1
  log("tap %d,%d -> %s | drawn %d ms | computer %d ms (%s) | total %d ms", x, y, b.id,
      (t_drawn - t0) * 1000, (t_computer - t_drawn) * 1000,
      answer and answer:gsub("%s+$", "") or "no answer", (now() - t0) * 1000)
  if taps % TAPS_BEFORE_FULL_REFRESH == 0 then draw_panel(true) end
end

while not quit do
  if ffi.C.poll(pfd, 1, 1000) > 0 then
    local len = ffi.C.read(fd, events, EVENT_SIZE * MAX_EVENTS)
    for i = 0, math.floor(len / EVENT_SIZE) - 1 do
      local ev = events[i]
      if ev.type == EV_ABS then
        if ev.code == ABS_MT_SLOT then
          slot = ev.value
        else
          fingers[slot] = fingers[slot] or {}
          local f = fingers[slot]
          if ev.code == ABS_MT_POSITION_X then
            f.x = ev.value; f.x0 = f.x0 or ev.value
          elseif ev.code == ABS_MT_POSITION_Y then
            f.y = ev.value; f.y0 = f.y0 or ev.value
          elseif ev.code == ABS_MT_TRACKING_ID then
            if ev.value == -1 then f.up = true else f.x0, f.y0 = nil, nil end
          end
        end
      elseif ev.type == EV_SYN and ev.code == 0 then
        for s, f in pairs(fingers) do
          if f.up then
            -- A tap is the first finger (slot 0) lifting close to where it landed.
            if s == 0 and f.x0 and f.y0 and math.abs((f.x or f.x0) - f.x0) < MAX_MOVE
               and math.abs((f.y or f.y0) - f.y0) < MAX_MOVE then
              on_tap(to_screen(f.x0, f.y0))
            end
            fingers[s] = nil
          end
        end
      end
    end
  elseif now() - last_check > LAYOUT_CHECK_SECONDS then
    last_check = now()
    local fresh = load_layout()
    if fresh and fresh.version ~= layout.version then
      log("new layout %s, redrawing", fresh.version)
      layout = fresh
      sh("rm -f " .. TMP .. "/*.png")
      draw_panel(true)
      preload(layout)
    end
  end
end

ffi.C.ioctl(fd, EVIOCGRAB, ffi.cast("void*", 0))
ffi.C.close(fd)
log("deck closed after %d taps", taps)
os.exit(0)
