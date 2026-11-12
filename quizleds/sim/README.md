# ledsim and treesim — the quizleds firmware on the host

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

`../src/string` and the shared transport in `../src` are compiled **unchanged**. `setup()`
and `loop()` are the firmware's own, so the frame pacing, the serial debug keys and
`network_tick()`'s command parsing are all the code that runs on the board.

NeoPixelBus' colour classes are also the library's own sources, compiled from
`../.pio/libdeps`. That matters more than it looks: `Counter::tick` and
`BuzzRainbow::tick` both round-trip a colour through the strip
(`HsbColor c = leds.GetPixelColor(i)`), which quantises float HSB down to 8-bit RGB and
back. The library truncates rather than rounds, so with 14 teams team 2 is `(255, 218, 0)`
and not `(255, 219, 0)`; reimplementing that maths would quietly change how those animations look.

Faked, in `shim/`:

| Shim | Stands in for | Behaviour |
|---|---|---|
| `Arduino.h` | the Arduino core | monotonic `millis`, `delay`, `random`, `String`, and a `Serial` wired to the terminal |
| `WiFi.h` | the ESP32 WiFi class | permanently connected, so `connectWifi()` succeeds first time |
| `esp_websocket_client.*` | the ESP-IDF websocket client | a real RFC6455 client over a POSIX socket, on its own thread, auto-reconnecting |
| `NeoPixelBus.h` | the bus only | keeps the pixel buffer the driver would DMA out; `Show()` hands it to the renderer |
| `tree_ring_shim.cpp` | the trees' RMT ring driver, `src/tree/tree_ring.cpp` | `ring_show()` hands the frame to the renderer |
| `esp_mac.h` | the core 3 header for `esp_read_mac()` | declared in the `Arduino.h` shim |
| `ota_shim.cpp` | firmware updates, `src/ota.cpp` | says what it would fetch, and carries on as if up to date |
| `freertos/*.h` | FreeRTOS queues | a thread-safe fixed-size FIFO with the same by-value copy semantics and timeouts |
| `credentials.h` | `../src/credentials.h` | only reached on a checkout that has never built the firmware |

The websocket runs on its own thread and delivers events from it, as the real client does.
That is why `web.cpp` hands each command to `loop()` through a FreeRTOS queue, which
`shim/freertos/` provides on the host with a mutex and condition variables.

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

## treesim — the desk trees

`make` also builds `./build/treesim`, which does the same for the desk trees: the firmware
in `../src/tree` and `../src/net.cpp`, compiled unchanged against the same shims.

    ./build/treesim -n 6

The interesting tree behaviour only appears with several trees connected (the `i`
identities, staggered buzzes, the room wave, the `w` ripple), but the tree firmware keeps
all of its state in file-scope statics, so one process can only be one tree. treesim
therefore `fork()`s a child per tree. Each child runs the firmware's own `setup()` and
`loop()` with a MAC address of its own, `02:00:00:51:00:<n>`, giving ids `510001`,
`510002` and so on, and opens its own websocket with `?tree=<id>`, so the server sees
separate trees in the order they are drawn. The parent runs no firmware: it owns the
terminal and reads each tree's ring from shared memory, its serial output from a pipe, and
sends it keystrokes down another. A tree whose parent has gone notices that pipe close and exits.

Each tree is drawn as its ring, LED 0 at the top and the rest clockwise, with its number,
its id and its state: `waiting` for the server, `n of m` once the server has given it a
place, `frozen` or `dead`.

Keys: **Tab** picks which tree the keys go to (all, or one). **X** kills it, so the
server sees the socket close at once. **S** starts it again from boot. **Z** freezes and
thaws it with SIGSTOP: its socket stays open but nothing answers, which is how a tree that
has lost power or WiFi looks until the server gives up on it. Every other key goes to the
firmware's debug console in `tree_main.cpp` (`0-7 b p r g k w = - i n x`).

### Colours

The bytes sent to a WS2812 set its PWM duty, so they are proportional to light, and
`tree_tick()` has already gamma corrected them for the eye. A monitor reads bytes as sRGB,
which is not linear, so the wire values drawn as they are look much darker than the tree
does. By default treesim encodes the light level as sRGB, which puts it on screen at about the brightness
it has on the desk. `--wire` draws the raw bytes, for checking the values themselves.

Options: `-n <trees>` (default 4, at most 32), `--uri`, `--wire`, `--plain`, `--seed`,
`--render-hz`, as for ledsim. With `--seed` each tree gets the seed plus its number, so the
run is reproducible but the trees still twinkle independently.

The serial pane shows the websocket URI from `credentials.h`, because that is what the
firmware prints. The shim connects to `--uri` instead, keeping the firmware's `?tree=` query.

### Showing the trees in Quiz Server

As ledsim does, treesim publishes the trees to a shared-memory file,
`/tmp/quiztreesim.frame` (`--frame-file`, `--no-frame-file`). The controller window
shows them as a row of rings, above the strip, with the same model: a one-line status while
treesim is not running, growing to make room when it appears and shrinking again 1.5s
after it goes. `treeshm.h` defines the layout and is the authority on it. It is pinned
with `static_assert`s in `treesim.cpp`, and `TreeFrameReader.swift` writes the same offsets
by hand.

The file is not a copy: the parent maps it before forking, so it is the memory the children
write their rings into, under a seqlock per tree. The parent writes the heartbeat, and each
tree's process state, so a frozen or dead tree is still shown rather than dropped. The app
applies the same sRGB encoding as the terminal view (`TreeRingsView.showWireValues` turns it off).

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
