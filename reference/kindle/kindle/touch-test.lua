-- Streamdeckify touch test: prints the touchscreen's ranges, then every touch
-- for a while, to check how touches map to screen pixels on a new Kindle.
-- Run it over SSH, with Amazon's interface running as usual:
--   cd /mnt/us/koreader && ./luajit /mnt/us/streamdeckify/touch-test.lua [device] [seconds]
-- Defaults: /dev/input/event1 for 600 seconds, because people tap slowly.
-- While it runs it takes the touchscreen for itself (EVIOCGRAB), so taps don't
-- reach the Kindle's interface. Ctrl-C ends it early.

local ffi = require("ffi")

ffi.cdef[[
int open(const char *pathname, int flags);
int ioctl(int fd, unsigned long request, void *arg);
int read(int fd, void *buf, size_t count);
int close(int fd);
typedef struct { int fd; short events; short revents; } pollfd;
int poll(pollfd *fds, unsigned long nfds, int timeout);
typedef struct { long tv_sec; long tv_usec; } timeval;
typedef struct { timeval time; uint16_t type; uint16_t code; int32_t value; } input_event;
typedef struct { int32_t value, minimum, maximum, fuzz, flat, resolution; } input_absinfo;
]]

local DEVICE = arg[1] or "/dev/input/event1"
local SECONDS = tonumber(arg[2] or "600")
local EVIOCGRAB = 0x40044590
local EVIOCGABS = 0x80184540 -- plus the axis code

local fd = ffi.C.open(DEVICE, 0)
if fd < 0 then print("can't open " .. DEVICE) os.exit(1) end

local axes = { { 0x2f, "SLOT" }, { 0x35, "POSITION_X" }, { 0x36, "POSITION_Y" }, { 0x39, "TRACKING_ID" } }
for _, axis in ipairs(axes) do
  local info = ffi.new("input_absinfo[1]")
  if ffi.C.ioctl(fd, EVIOCGABS + axis[1], info) == 0 then
    print(string.format("ABS_MT_%s: min %d, max %d", axis[2], info[0].minimum, info[0].maximum))
  end
end

if ffi.C.ioctl(fd, EVIOCGRAB, ffi.cast("void*", 1)) ~= 0 then
  print("EVIOCGRAB failed (errno " .. ffi.errno() .. "): something else holds the touchscreen")
else
  print("EVIOCGRAB ok: the touchscreen is ours until the test ends")
end
print(string.format("Tap the four corners, then the middle. Listening for %d seconds.", SECONDS))
io.stdout:flush()

local pfd = ffi.new("pollfd[1]")
pfd[0].fd = fd
pfd[0].events = 1 -- POLLIN
local SIZE = ffi.sizeof("input_event")
local events = ffi.new("input_event[?]", 64)
local slot, fingers, count, t0 = 0, {}, 0, os.time()
while os.time() - t0 < SECONDS do
  if ffi.C.poll(pfd, 1, 500) > 0 then
    local len = ffi.C.read(fd, events, SIZE * 64)
    for i = 0, math.floor(len / SIZE) - 1 do
      local ev = events[i]
      if ev.type == 3 then
        if ev.code == 0x2f then
          slot = ev.value
        else
          fingers[slot] = fingers[slot] or {}
          local f = fingers[slot]
          if ev.code == 0x35 then f.x = ev.value
          elseif ev.code == 0x36 then f.y = ev.value
          elseif ev.code == 0x39 then f.event = (ev.value == -1) and "UP" or "DOWN" end
        end
      elseif ev.type == 0 and ev.code == 0 then
        for s, f in pairs(fingers) do
          if f.event then
            count = count + 1
            print(string.format("%-4s slot %d x %s y %s", f.event, s, tostring(f.x), tostring(f.y)))
            io.stdout:flush()
            f.event = nil
          end
        end
      end
    end
  end
end
ffi.C.ioctl(fd, EVIOCGRAB, ffi.cast("void*", 0))
ffi.C.close(fd)
print("touch events: " .. count)
