# ledsim — the quizleds firmware on the host

Runs the real firmware as a native executable and draws the strip in the terminal, so the
LED code and its interaction with the rest of the quiz can be tested without a board.

    make
    ./build/ledsim

It connects to the node server's LED port (`ws://127.0.0.1:8092/` by default) exactly as
the ESP32 does, and the server cannot tell the difference: it logs "LED controller
connected", sends `a01`, and the strip starts on Megamas. Everything upstream of that —
Quiz Server, `protocol.js`, the `le` routing — is untouched and unaware.

    Quiz Server ──ws:8091──▶ node server ──ws:8092──▶ ledsim

## What is real and what is not

`../src` is compiled **unchanged**. `setup()` and `loop()` are the firmware's own, so the
frame pacing, the serial debug keys and `network_tick()`'s command parsing are all the
code that runs on the board.

NeoPixelBus' colour classes are also the library's own sources, compiled from
`../.pio/libdeps`. That matters more than it looks: `Counter::tick` and
`BuzzRainbow::tick` both round-trip a colour through the strip
(`HsbColor c = leds.GetPixelColor(i)`), which quantises float HSB down to 8-bit RGB and
back. The library truncates rather than rounds, so team 3 is `(50, 255, 0)` and not
`(51, 255, 0)`; reimplementing that maths would quietly change how those animations look.

Faked, in `shim/`:

| Shim | Stands in for | Behaviour |
|---|---|---|
| `Arduino.h` | the Arduino core | monotonic `millis`, `delay`, `random`, `String`, and a `Serial` wired to the terminal |
| `WiFi.h` | the ESP32 WiFi class | permanently connected, so `connectWifi()` succeeds first time |
| `esp_websocket_client.*` | the ESP-IDF websocket client | a real RFC6455 client over a POSIX socket, on its own thread, auto-reconnecting |
| `NeoPixelBus.h` | the bus only | keeps the pixel buffer the driver would DMA out; `Show()` hands it to the renderer |
| `credentials.h` | `../src/credentials.h` | only reached on a checkout that has never built the firmware |

The websocket runs on its own thread and delivers events from it, as the real client does.
That is why `web.cpp` copies each command into `command_to_parse` and parses it later from
`loop()`; the same race is present here, which is the point.

## Options

    --uri <ws://host:port/>  LED websocket to connect to (default ws://127.0.0.1:8092/)
    --wiring                 show the raw physical strip rather than the line it forms
    --plain                  no alternate screen or raw input; serial goes to stdout
    --seed <n>               fixed random seed, for reproducible animations
    --render-hz <n>          terminal redraw rate (default 30)
    --frame-file <path>      shared frame file (default /tmp/quizledsim.frame)
    --no-frame-file          do not publish frames

The layout adapts to the window: the status line and the strip are always drawn in full,
and the serial pane and the footer are dropped when there is not enough height for them,
so the display never scrolls.

Keystrokes go to the firmware's own debug console in `main.cpp` (`m s e l o r g b z c p = -`,
where `s`, `e` and `l` are the three background animations),
because the shim's `Serial` reads the terminal. ctrl-C quits.

### Animation order vs wiring order

The strip is physically folded, so the LEDs are not in the order they appear on the wall.
`ledlookup` undoes that: animation index 0..199 is the line left to right, which is the
space the animations are written in and what is drawn by default.

`--wiring` shows the raw physical run instead, which is what you want when checking the
mapping itself rather than the animation. Setting the counter to 50 shows the difference:

    animation order WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW..  (50 contiguous)
    wiring order    WWWWWWWWWWWWWWWWWWWWWWWWW..........................  (25 at each end)
                    ...........................WWWWWWWWWWWWWWWWWWWWWWWWW

## Showing the strip in Quiz Server

Every frame is also published to a small shared-memory file, which the controller window
reads to draw the strip along the bottom. The window carries only a one-line status while
no simulator is running, and grows to make room for the strip when one appears. `frameshm.h` defines the layout and is the
authority on it: the Swift reader in `Quiz Server/Quiz Server/LEDMonitor/` hand-writes the
same offsets, and every one of them is pinned here with a `static_assert`.

The mapping is the memory ledsim writes to, so nothing on the reading side can ever stall
the animation loop -- a reader that falls behind simply misses frames. Several readers can
watch at once, which is why the terminal view above keeps working while the app is showing
the same strip.

Liveness is the `heartbeat` field, written from `loop()` and not from `Show()`. It has to
be: an animation that has settled stops producing frames entirely and holds its last one,
exactly as real LEDs do, so "no new frames" is a resting state and not a sign that ledsim
has gone away.

The file is created if absent and never truncated or unlinked, so ledsim can be restarted
underneath a reader that has already mapped it.

## Driving it without the Swift app

`drive.js` starts the node server's websocket listeners and plays commands at them as
Quiz Server would:

    node drive.js                 demo tour of every animation, looping
    node drive.js a01 b03 r050    send those commands and exit
    node drive.js --server-only   run the server and type commands on stdin

## Requirements

A C++11 compiler and `make`. NeoPixelBus is taken from `../.pio/libdeps`, which is
gitignored, so a fresh checkout needs `pio pkg install -e main` in `..` first — the same
step the firmware build needs.
