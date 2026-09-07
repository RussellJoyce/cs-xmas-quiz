# LED simulator — known issues

Recorded 2026-09-05, after building `quizleds/sim` and the controller-window monitor.
Nothing here is fixed; this is a list to come back to.

The simulator compiles the real firmware sources unchanged and fakes only the ESP-specific
layer (`quizleds/sim/shim/`). The entries below are places where that fake differs from the
board in ways that matter, plus bugs in the simulator itself, plus firmware problems the
simulator has surfaced but which have not been dealt with.


## 1. Fidelity gaps — things the simulator cannot tell you

These are the dangerous ones, because the simulator looks perfectly healthy while the board
would not be.

### 1.1 No websocket keepalive

`quizleds/sim/shim/esp_websocket_client.cpp`

The real ESP-IDF client pings on a timer and drops the connection when the replies stop.
From the header in the installed toolchain
(`~/.platformio/packages/framework-arduinoespressif32/tools/sdk/*/include/esp_websocket_client/include/esp_websocket_client.h`):

```c
size_t ping_interval_sec;      /*!< defaults to 10 seconds if not set */
int    pingpong_timeout_sec;   /*!< Period before connection is aborted due to no PONGs received */
bool   disable_pingpong_discon;
```

The shim never sends a ping and never times out. Consequences:

* A half-open connection (server machine disappears without sending a FIN) is invisible to
  the simulator, which will believe it is connected indefinitely. The board would notice
  and reconnect within roughly ten to twenty seconds.
* `web.cpp:97` (`case 10: //keep alive ping. ignore.`) is never exercised, because that case
  handles the PONG replies to the client's *own* pings.

Adding a ping timer to the shim is around ten lines and would make reconnection behaviour
real. Worth doing if the strip has ever wedged in a way a reconnect would have cleared.

Incidentally, the comment at `web.cpp:97` is slightly wrong: opcode 10 is PONG, not ping.
Opcode 9 is PING, which the shim does answer.

### 1.2 `Show()` costs nothing on the host

`quizleds/sim/shim/NeoPixelBus.h`

On the board, pushing 200 LEDs is 200 × 24 bits at 800 kHz, so about **6 ms of transmission
against a 13 ms frame budget** (`MILLIS_PER_FRAME` in `settings.h`). In the simulator
`Show()` is a `memcpy`.

The simulator therefore reports a comfortable 74–77 fps no matter how expensive an
animation is, and cannot warn about frame-budget pressure. The current animations are all
cheap; a future one that is not would look fine in the simulator and stutter on the strip.

Modelling this properly is a lot of machinery for something the bench would show
immediately, so this is probably documentation rather than a fix.

### 1.3 `unsigned long` is 64-bit on the host, 32-bit on the ESP32

`quizleds/sim/shim/arduino_shim.cpp`

Measured: `sizeof(unsigned long)` is 8 on macOS arm64 and 4 in the Arduino ESP32 core. So
`millis()` arithmetic differs, and the simulator can never reproduce the 49.7-day wrap.

This hides a real latent bug in `main.cpp:31-37`:

```c
static volatile unsigned long next_frame_time = 0;
unsigned long current_time = millis();
if(current_time >= next_frame_time) {
        anim_tick();
        next_frame_time = current_time + MILLIS_PER_FRAME;
}
```

That comparison is not wrap-safe. At the wrap, `current_time` restarts near zero while
`next_frame_time` is still near 2^32, so animation ticking stops until the clock catches up
— another 49.7 days. Irrelevant for a quiz that runs for an evening, and the fix is the
usual `(long)(current_time - next_frame_time) >= 0` form, but the simulator will never
find this class of bug on its own.

### 1.4 `random()` is deterministic in the simulator

`quizleds/sim/shim/arduino_shim.cpp`

The shim implements `random()` on top of `rand()`, seeded by `--seed`. Arduino on the ESP32
backs `random()` with the hardware RNG. Reproducibility across runs is a property of the
simulator, not of the board — useful for testing, but do not read "it looked the same both
times" as meaning the board will.

The firmware also calls `rand()`/`RAND_MAX` directly in places, which on the host shares
state with `random()` and on the board does not.


## 2. Simulator bugs and rough edges

### 2.1 A frame-file failure is invisible

`quizleds/sim/frameshm.cpp:46`

`frameshm_open` reports failure with `fprintf(stderr, ...)`. In the normal full-screen mode
the renderer homes the cursor and overwrites it immediately, so a frame file that cannot be
opened produces no monitor in the app and no visible explanation.

Fix: surface it on the status line instead of, or as well as, stderr.

### 2.2 Two simulator instances share one frame file

`quizleds/sim/frameshm.cpp`

Nothing stops two `ledsim` processes opening the same frame file and interleaving writes
into it. There is no lock and no warning; the monitor would show an incoherent mixture.

Fix: `flock` the file at open and refuse, with a clear message, if it is already held.

### 2.3 The seqlock is not formally airtight on either side

`quizleds/sim/frameshm.cpp:87,95` and `Quiz Server/Quiz Server/LEDMonitor/LEDFrameReader.swift`

The writer brackets the pixel copy with `std::atomic_thread_fence(memory_order_release)`
either side of a plain, non-atomic `shm->seq++`. The standard defines fences in terms of
*atomic* operations, so this relies on clang and gcc treating the fence as a full compiler
barrier. Both do, but it is implementation behaviour rather than a guarantee.

Fix on the writer is cheap and worth taking: make `seq` a `std::atomic<uint32_t>`. Same
size, same offset, so neither the layout nor the Swift reader changes.

The reader has the same caveat with no cheap fix — Swift has no portable memory fence
without swift-atomics. Given this is a 77 Hz monitor, the worst case is a single frame
showing a boundary between two others for about 13 ms, which is not visible.

### 2.4 A stalled terminal blocks the whole simulator

`quizleds/sim/simmain.cpp:268`

The renderer writes to stdout with a blocking write. If the terminal stops being consumed —
ctrl-S, a stopped process, a full scrollback — the write blocks inside `loop()` and the
simulated firmware stops.

Measured behaviour, which is benign but worth knowing:

```
before any key                     frames=0      heartbeat age=0.09s
swell running, terminal read       frames=149    heartbeat age=0.08s
after 3s of not reading pty        frames=149    heartbeat age=3.08s   <- loop fully blocked
after resuming reads               frames=223    heartbeat age=0.10s   <- recovers
```

The heartbeat stalls along with everything else, so the app correctly reports "not running"
rather than presenting a frozen strip as live, and it recovers when reading resumes. Use
`--plain`, or redirect stdout, if only the in-app monitor is wanted.

### 2.5 `Serial.printf` truncates at 512 bytes

`quizleds/sim/shim/Arduino.h:109`

The shim formats into a fixed 512-byte buffer. The board's `Print::printf` has no such
limit. Nothing currently prints anything near that long.

### 2.6 `--seed 0` silently means "seed from the clock"

`quizleds/sim/simmain.cpp:371`

```c
randomSeed(opts.seed ? opts.seed : (unsigned long) time(0));
```

Passing `--seed 0` explicitly gets clock seeding rather than a seed of zero. Wants a
separate "was the flag given" flag.

### 2.7 `ledsim` never exits on stdin EOF

By design — it is a device simulator, not a filter — but it means scripts driving it must
kill it rather than closing its input. Worth knowing before writing a test harness.


## 3. Firmware problems found but not fixed

These are in `quizleds/src`, not in the simulator.

### 3.1 A `String` is passed through varargs

`quizleds/src/web.cpp:53`

```c
Serial.printf("Attempting SSID: %s\n", wifi_ssid);   // wifi_ssid is a String
```

Undefined behaviour. It very probably works by accident on the board, because Arduino's
`String` has `char *buffer` as its first member, so GCC pushes the object and `%s` reads
that first word as the pointer. The fix is `wifi_ssid.c_str()`.

The simulator papers over this: `SerialClass::printf` in the shim is a variadic template
specifically so that a `String` argument is converted on the way through. Fixing the
firmware would let that become a plain `vsnprintf`.

### 3.2 `ledlookup` is `uint8_t[]`, capping `NUM_LEDS` at 256

`quizleds/src/ledmapping.h:6`

```c
extern const uint8_t ledlookup[];
extern const uint8_t ledlookup_rand[];
```

`NUM_LEDS` is 200 so this is fine today, but raising it past 256 would silently truncate
every mapped index rather than failing to build.

### 3.3 `BuzzCentre` only sweeps one half

`quizleds/src/animation.cpp:472`

```c
current[ledlookup_clamp(NUM_LEDS/2-(framenum*2+i), false)] = ...
```

With `framenum` running 0..49 this covers animation indices 98 down to 1 — the centre of
the line out to the left-hand end — and never 100 up to 199. The right-hand half gets no
random-colour sparkle and simply fades in with the fill at `framenum == NUM_LEDS/4 + 20`.

Possibly deliberate, but it does not match the name. Not investigated further.

### 3.4 `command_to_parse` clamping

`quizleds/src/web.cpp:92`

A 20-byte message exactly fills the buffer, leaving no terminator. Benign in practice —
nothing reads it as a C string, and no command is close to 20 bytes — but `>=` would be
more obviously correct than `>`.
