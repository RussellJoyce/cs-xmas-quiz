/*
Simulator front end: owns the terminal, and stands in for the Arduino core's main loop.

The firmware's own setup() and loop() are used unchanged, so what runs here is the real
scheduling: loop() spins, ticks the animation once every MILLIS_PER_FRAME, drains the
serial debug keys and calls network_tick() to pick up whatever the websocket thread left
in command_to_parse.
*/

#include <Arduino.h>
#include <NeoPixelBus.h>
#include <esp_websocket_client.h>
#include "frameshm.h"
#include <settings.h>
#include <ledmapping.h>

#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>
#include <signal.h>
#include <poll.h>
#include <time.h>

#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <deque>
#include <string>
#include <thread>
#include <vector>

//From the firmware
void setup();
void loop();

namespace {

//-------------------------------------------------------------------------------------------------
// Options

struct Options {
	std::string uri = "ws://127.0.0.1:8092/";
	//Animation order by default: the strip is folded, so index 0..199 through ledlookup is
	//the left-to-right line people actually see. Wiring order is the raw physical run.
	bool logical = true;
	bool plain = false;        //No alternate screen or raw input, for piping to a file
	unsigned long seed = 0;    //0 means seed from the clock
	int renderHz = 30;
	std::string frameFile = FRAMESHM_DEFAULT_PATH;  //Empty disables publishing
};
Options opts;

//-------------------------------------------------------------------------------------------------
// Terminal

//Everything the renderer puts on screen goes through here: stdio buffering and raw
//writes to the same descriptor would otherwise be free to interleave in either order.
void emit(const char* data, size_t len) {
	size_t written = 0;
	while(written < len) {
		ssize_t n = write(STDOUT_FILENO, data + written, len - written);
		if(n <= 0) return;
		written += (size_t) n;
	}
}
void emit(const char* s) { emit(s, strlen(s)); }

struct termios saved_termios;
bool termios_saved = false;
volatile sig_atomic_t quit = false;

bool terminal_restored = false;

void restoreTerminal() {
	if(terminal_restored) return;
	terminal_restored = true;
	if(termios_saved) {
		tcsetattr(STDIN_FILENO, TCSANOW, &saved_termios);
		termios_saved = false;
	}
	if(!opts.plain) emit("\x1b[?25h\x1b[?1049l"); //Show cursor, leave alt screen
	fflush(stdout);
}

void onSignal(int) { quit = true; }

void setupTerminal() {
	if(opts.plain) return;

	if(isatty(STDIN_FILENO) && tcgetattr(STDIN_FILENO, &saved_termios) == 0) {
		termios_saved = true;
		struct termios raw = saved_termios;
		//Unbuffered, unechoed input so the firmware's debug keys arrive a keypress at a
		//time. ISIG is deliberately left on so that ctrl-C still quits.
		raw.c_lflag &= ~(ICANON | ECHO);
		raw.c_cc[VMIN] = 0;
		raw.c_cc[VTIME] = 0;
		tcsetattr(STDIN_FILENO, TCSANOW, &raw);
	}
	atexit(restoreTerminal);
	emit("\x1b[?1049h\x1b[?25l\x1b[2J"); //Alt screen, hide cursor, clear
}

void terminalSize(int* rows, int* cols) {
	struct winsize ws;
	if(ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col > 20 && ws.ws_row > 2) {
		*rows = ws.ws_row;
		*cols = ws.ws_col;
	} else {
		*rows = 24;
		*cols = 100;
	}
}

//Visible width, ignoring SGR escapes, so a line can be truncated to the terminal without
//cutting an escape sequence in half.
size_t visibleLen(const std::string& s) {
	size_t n = 0;
	for(size_t i = 0; i < s.size(); i++) {
		if(s[i] == '\x1b') {
			while(i < s.size() && !isalpha((unsigned char) s[i])) i++;
		} else if((s[i] & 0xc0) != 0x80) {
			n++; //Count a UTF-8 sequence once, not once per byte
		}
	}
	return n;
}

//-------------------------------------------------------------------------------------------------
// Serial console state. Output is kept as a scrollback drawn under the strip; input comes
// straight from the terminal, so main.cpp's debug keys work as they do over a real UART.

std::deque<std::string> log_lines;
std::string log_partial;
const size_t LOG_ROWS = 8;

//available() has to peek at stdin, so the byte it consumed is held back for read().
char key_peeked = 0;
bool key_pending = false;

//-------------------------------------------------------------------------------------------------
// Renderer state

RgbColor frame[NUM_LEDS];
unsigned long shows = 0;
unsigned long shows_at_last_sample = 0;
double measured_fps = 0.0;
std::chrono::steady_clock::time_point last_render;
std::chrono::steady_clock::time_point last_fps_sample;
int last_rows = 0;
int last_cols = 0;

//A full block in the pixel's colour. 24-bit colour is assumed; there is no sensible
//256-colour fallback for arbitrary RGB.
void render();
void beat();

void appendPixel(std::string& out, const RgbColor& c) {
	char buf[32];
	snprintf(buf, sizeof(buf), "\x1b[38;2;%u;%u;%um" "█", c.R, c.G, c.B);
	out += buf;
}

//Redraws at the terminal's rate rather than the animation's, and keeps going when nothing
//is animating so the connection status stays live.
void maybeRender() {
	if(opts.plain) return;

	const auto now = std::chrono::steady_clock::now();
	if(std::chrono::duration_cast<std::chrono::milliseconds>(now - last_fps_sample).count() >= 1000) {
		measured_fps = (double) (shows - shows_at_last_sample);
		shows_at_last_sample = shows;
		last_fps_sample = now;
	}
	if(std::chrono::duration_cast<std::chrono::milliseconds>(now - last_render).count() < 1000 / opts.renderHz) {
		return;
	}
	last_render = now;
	render();
}

//10Hz is ample for a reader using a sub-second staleness threshold, and keeps this off
//the clock on every one of the ~1000 loop iterations a second.
void beat() {
	static std::chrono::steady_clock::time_point last;
	const auto now = std::chrono::steady_clock::now();
	if(std::chrono::duration_cast<std::chrono::milliseconds>(now - last).count() < 100) return;
	last = now;
	frameshm_heartbeat();
}

void render() {
	int rows = 0, cols = 0;
	terminalSize(&rows, &cols);

	const int perRow = (cols - 6) < NUM_LEDS ? (cols - 6) : NUM_LEDS;
	if(perRow < 1 || rows < 3) return;

	//A resize leaves debris from the old layout, so start that frame from a clean screen.
	if(rows != last_rows || cols != last_cols) {
		last_rows = rows;
		last_cols = cols;
		emit("\x1b[2J");
	}

	std::vector<std::string> lines;
	char buf[256];

	//Coloured if it fits, plain and truncated if not, so the line never wraps.
	snprintf(buf, sizeof(buf), " ledsim  %s  %s  last '%s'  %lu frames  %.1f fps",
	         sim_websocket_is_connected() ? "connected" : "waiting for server",
	         opts.logical ? "animation order" : "wiring order",
	         sim_websocket_last_message(), shows, measured_fps);
	if((int) strlen(buf) <= cols) {
		snprintf(buf, sizeof(buf),
		         "\x1b[1m ledsim\x1b[0m  %s  %s  last '%s'  %lu frames  %.1f fps",
		         sim_websocket_is_connected() ? "\x1b[32mconnected\x1b[0m"
		                                      : "\x1b[31mwaiting for server\x1b[0m",
		         opts.logical ? "animation order" : "wiring order",
		         sim_websocket_last_message(), shows, measured_fps);
		lines.push_back(buf);
	} else {
		lines.push_back(std::string(buf).substr(0, cols));
	}
	lines.push_back("");

	for(int i = 0; i < NUM_LEDS; i += perRow) {
		snprintf(buf, sizeof(buf), "\x1b[90m%4d\x1b[0m ", i);
		std::string row = buf;
		for(int j = i; j < i + perRow && j < NUM_LEDS; j++) {
			appendPixel(row, opts.logical ? frame[ledlookup[j]] : frame[j]);
		}
		row += "\x1b[0m";
		lines.push_back(row);
	}

	//The serial pane and the footer are what get dropped when the window is too short,
	//so the strip itself is always drawn in full rather than scrolling off.
	const int spare = rows - (int) lines.size();
	if(spare >= 4) {
		const size_t room = (size_t) (spare - 3);
		const size_t shown = room < LOG_ROWS ? room : LOG_ROWS;
		lines.push_back("");
		lines.push_back("\x1b[90m--- serial ---\x1b[0m");
		for(size_t i = 0; i < shown; i++) {
			if(i < log_lines.size()) lines.push_back(log_lines[i]);
			//The tail of a print() that has not ended in a newline yet, such as main.cpp's '#'
			else if(i == log_lines.size()) lines.push_back(log_partial);
			else lines.push_back("");
		}
		const std::string footer =
			"\x1b[90mkeys go to the firmware's debug console (m o r g b z c p = -), ctrl-C to quit\x1b[0m";
		lines.push_back(visibleLen(footer) <= (size_t) cols ? footer : "");
	}

	//Home, then overwrite in place. No newline after the last line, and never more lines
	//than the window has, so the terminal is never made to scroll.
	std::string out = "\x1b[H";
	const size_t limit = lines.size() < (size_t) rows ? lines.size() : (size_t) rows;
	for(size_t i = 0; i < limit; i++) {
		out += lines[i];
		out += "\x1b[K";
		if(i + 1 < limit) out += "\n";
	}
	out += "\x1b[J"; //Clear anything the previous, taller frame left below

	emit(out.data(), out.size());
}

} //namespace

//-------------------------------------------------------------------------------------------------
// Hooks called by the shims

void sim_serial_out(const char* text, size_t len) {
	if(opts.plain) {
		fwrite(text, 1, len, stdout);
		fflush(stdout);
		return;
	}
	for(size_t i = 0; i < len; i++) {
		if(text[i] == '\n') {
			log_lines.push_back(log_partial);
			while(log_lines.size() > LOG_ROWS) log_lines.pop_front();
			log_partial.clear();
		} else if(text[i] != '\r') {
			log_partial += text[i];
		}
	}
}

int sim_serial_available() {
	if(key_pending) return 1;
	//poll rather than a non-blocking read: stdin, stdout and stderr on a terminal are
	//dups of one open file description, so setting O_NONBLOCK here would make writes to
	//the screen non-blocking too and truncate a frame whenever the tty buffer filled.
	struct pollfd p;
	p.fd = STDIN_FILENO;
	p.events = POLLIN;
	if(poll(&p, 1, 0) <= 0) return 0;
	char c;
	if(read(STDIN_FILENO, &c, 1) == 1) {
		key_peeked = c;
		key_pending = true;
		return 1;
	}
	return 0;
}

int sim_serial_read() {
	if(key_pending) {
		key_pending = false;
		return (unsigned char) key_peeked;
	}
	char c;
	if(read(STDIN_FILENO, &c, 1) == 1) return (unsigned char) c;
	return -1;
}

//Called by the NeoPixelBus shim's Show(). Always on the loop() thread: the websocket
//thread only ever copies a command out, exactly as it does on the board.
void sim_leds_show(const RgbColor* pixels, uint16_t count) {
	const uint16_t n = count < NUM_LEDS ? count : NUM_LEDS;
	memcpy(frame, pixels, n * sizeof(RgbColor));
	shows++;

	if(frameshm_active()) {
		//Copied component by component rather than memcpy'd: RgbColor is very likely three
		//packed bytes, but nothing in the library promises it.
		static uint8_t rgb[NUM_LEDS * 3];
		for(uint16_t i = 0; i < n; i++) {
			rgb[i * 3 + 0] = pixels[i].R;
			rgb[i * 3 + 1] = pixels[i].G;
			rgb[i * 3 + 2] = pixels[i].B;
		}
		frameshm_write(rgb, n);
	}
}

//-------------------------------------------------------------------------------------------------

static void usage() {
	fprintf(stderr,
		"ledsim - runs the quizleds firmware on the host and draws the strip in the terminal\n\n"
		"  --uri <ws://host:port/>  LED websocket to connect to (default ws://127.0.0.1:8092/)\n"
		"  --wiring                 show the raw physical strip rather than the line it forms\n"
		"  --plain                  no alternate screen or raw input; serial goes to stdout\n"
		"  --seed <n>               fixed random seed, for reproducible animations\n"
		"  --render-hz <n>          terminal redraw rate (default 30)\n"
		"  --frame-file <path>      shared frame file for other viewers\n"
		"                           (default " FRAMESHM_DEFAULT_PATH ")\n"
		"  --no-frame-file          do not publish frames\n"
		"  --help\n");
}

int main(int argc, char** argv) {
	for(int i = 1; i < argc; i++) {
		std::string a = argv[i];
		if(a == "--uri" && i + 1 < argc) opts.uri = argv[++i];
		else if(a == "--wiring") opts.logical = false;
		else if(a == "--plain") opts.plain = true;
		else if(a == "--seed" && i + 1 < argc) opts.seed = strtoul(argv[++i], 0, 10);
		else if(a == "--render-hz" && i + 1 < argc) opts.renderHz = atoi(argv[++i]);
		else if(a == "--frame-file" && i + 1 < argc) opts.frameFile = argv[++i];
		else if(a == "--no-frame-file") opts.frameFile.clear();
		else { usage(); return a == "--help" ? 0 : 1; }
	}
	if(opts.renderHz < 1) opts.renderHz = 1;

	randomSeed(opts.seed ? opts.seed : (unsigned long) time(0));
	sim_websocket_set_uri(opts.uri.c_str());

	//ledlookup is published alongside the pixels so that a viewer can offer the same
	//wiring/animation order choice without keeping its own copy of the table.
	if(!opts.frameFile.empty()) {
		frameshm_open(opts.frameFile.c_str(), NUM_LEDS, ledlookup, NUM_LEDS);
	}

	signal(SIGINT, onSignal);
	signal(SIGTERM, onSignal);
	setupTerminal();

	last_render = last_fps_sample = std::chrono::steady_clock::now();

	setup();
	while(!quit) {
		loop();
		maybeRender();
		beat();
		//The real loop() is called back to back by the Arduino core. A short sleep keeps
		//the simulator off a spinning core without affecting the 13ms frame timing.
		std::this_thread::sleep_for(std::chrono::milliseconds(1));
	}

	restoreTerminal();
	frameshm_close();
	return 0;
}
