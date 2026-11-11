---
name: Kindle Paperwhite 2
brand: Amazon
year: 2013
family: kindle
screen: e-ink
input: [touch]
method: jailbreak
prompt: kindle
status: verified
latency_ms: 200
computers: [macos, linux]
contributors: [enzovalley9]
summary: The first one. Jailbroken with WinterBreak2, a LuaJIT client on the Kindle, about 200 ms from tap to app.
updated: 2026-11-09
---

The sixth generation Paperwhite, Wi-Fi only. This project started with one: it sits next to a monitor and runs a Mac mini and an Ubuntu PC, switching between them with two launchers in the library.

## What worked

| | |
| --- | --- |
| Firmware | 5.12.2.1.1 (Amazon only offers 5.12.2.2 for this model now) |
| Jailbreak | WinterBreak2, following kindlemodding.org (October 2026). It blocks over-the-air updates as part of the process. |
| Shell | KOReader's `kindlepw2` build: its dropbear on port 2222, key-only, started from a launcher in the library |
| Client | `deck.sh` (pauses and restores the Kindle UI) and `deck.lua` (the loop) from `reference/kindle/`, on KOReader's LuaJIT with FFI |
| Drawing | The jailbreak's FBInk; KOReader's build has no image support |
| Screen | 758 x 1024, 8 bits per pixel, 212 dpi |
| Touch | `/dev/input/event1` (`cyttsp4_mt`), multitouch type B, X 0 to 757 and Y 0 to 1023, 1:1 with pixels |
| Speed | From a tap to the Mac's answer, 70 to 209 ms in the Kindle's log (median 139 ms over 21 taps). Then on the Mac, apps open in 89 to 362 ms, play/pause in Spotify takes 155 to 408 ms, and key presses 207 to 282 ms, or up to 1.7 s while dictation is recording. |

## Gotchas

- Stopping only the window manager (`awesome`) isn't enough: X clients repaint over the panel. Stop `Xorg` too, and continue both on exit.
- Reset `preventScreenSaver` to 0 when the panel closes, or the power button stops putting the Kindle to sleep.
- The touch controller sometimes splits one tap into two contacts 60 to 150 ms apart. A half-second debounce per button fixes it.
- The Kindle drops ping. Use TCP to check that it's alive.
- 256 MB of RAM with about 80 free, and kernel 3.0.35. If you compile Go for it, use Go 1.23 or older.
- UDP discovery works when the Kindle sends to the subnet's broadcast address (like 192.168.1.255), not to 255.255.255.255.
- Right after waking up, the Wi-Fi takes a moment: the first try at the computer's address can fail. UDP discovery found it on its second try.
- On the Mac, key presses go through a small helper app that holds the Accessibility permission. Python launched by launchd never got it to stick.
