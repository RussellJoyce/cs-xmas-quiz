/*
treesim: several desk trees on the host, drawn side by side in the terminal.

The tree firmware keeps all of its state in file-scope statics, so one process can only ever
be one tree. Rather than change the firmware, the parent fork()s a child per tree. Each child
runs the firmware's own setup() and loop() with a MAC address of its own, and so has its own
state, its own websocket and its own place among the trees, exactly as separate boards do. The
server cannot tell them from real trees.

The parent never runs any firmware code. It owns the terminal, and talks to each child over:
  - a shared memory slot, which the child's Show() writes the ring into under a seqlock
  - a pipe the child's Serial writes to, which the parent shows in the serial pane
  - a pipe the parent writes keystrokes to, which the child's Serial reads, so the firmware's
    debug keys work. Its closing is also how a child notices that the parent has gone.

Because the parent never starts a thread, fork() is safe: each child begins as a copy of a
single-threaded process and starts its own websocket thread from setup().
*/

#include <Arduino.h>
#include <NeoPixelBus.h>
#include <esp_websocket_client.h>
#include <tree_settings.h>
#include "treeshm.h"

#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <poll.h>
#include <time.h>

#include <atomic>
#include <cerrno>
#include <chrono>
#include <cmath>
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

const int MAX_TREES = TREESHM_MAX;
static_assert(TREE_NUM_LEDS == TREESHM_LEDS, "treeshm.h carries 8 LEDs a tree");

//The Swift reader hand-writes these offsets, so pin every one of them here
static_assert(offsetof(TreeShm, magic)          ==    0, "TreeShm.magic moved");
static_assert(offsetof(TreeShm, version)        ==    4, "TreeShm.version moved");
static_assert(offsetof(TreeShm, trees)          ==    8, "TreeShm.trees moved");
static_assert(offsetof(TreeShm, leds)           ==   12, "TreeShm.leds moved");
static_assert(offsetof(TreeShm, heartbeat)      ==   16, "TreeShm.heartbeat moved");
static_assert(offsetof(TreeShm, slot)           ==   32, "TreeShm.slot moved");
static_assert(sizeof(TreeShm)                   == 3104, "TreeShm size changed");
static_assert(offsetof(TreeShmSlot, seq)        ==    0, "TreeShmSlot.seq moved");
static_assert(offsetof(TreeShmSlot, process)    ==    4, "TreeShmSlot.process moved");
static_assert(offsetof(TreeShmSlot, frames)     ==    8, "TreeShmSlot.frames moved");
static_assert(offsetof(TreeShmSlot, index)      ==   16, "TreeShmSlot.index moved");
static_assert(offsetof(TreeShmSlot, count)      ==   20, "TreeShmSlot.count moved");
static_assert(offsetof(TreeShmSlot, connected)  ==   24, "TreeShmSlot.connected moved");
static_assert(offsetof(TreeShmSlot, id)         ==   32, "TreeShmSlot.id moved");
static_assert(offsetof(TreeShmSlot, rgb)        ==   40, "TreeShmSlot.rgb moved");
static_assert(offsetof(TreeShmSlot, last)       ==   64, "TreeShmSlot.last moved");
static_assert(sizeof(TreeShmSlot)               ==   96, "TreeShmSlot size changed");

//-------------------------------------------------------------------------------------------------
// Options

struct Options {
	std::string uri = "ws://127.0.0.1:8092/";
	int trees = 4;
	bool wire = false;         //Draw the bytes sent to the LEDs rather than what they look like
	bool plain = false;        //No alternate screen or raw input; serial goes to stdout
	unsigned long seed = 0;    //0 means seed from the clock
	int renderHz = 30;
	std::string frameFile = TREESHM_DEFAULT_PATH;  //Empty: share anonymous memory instead
};
Options opts;

//-------------------------------------------------------------------------------------------------
// Shared memory: one slot per tree, written by the child, read by the parent and by anyone
// else who maps the frame file. See treeshm.h.

typedef TreeShmSlot Slot;
TreeShm* shm = 0;
Slot* slots = 0;

double nowSeconds() {
	struct timespec ts;
	clock_gettime(CLOCK_REALTIME, &ts);
	return (double) ts.tv_sec + (double) ts.tv_nsec / 1e9;
}

//The frame file if it can be had, otherwise anonymous memory, which works just as well
//between treesim's own processes. Either way it is mapped before any child is forked.
void mapShared() {
	void* p = MAP_FAILED;
	if(!opts.frameFile.empty()) {
		//No O_TRUNC, as in frameshm.cpp: a new inode would strand a reader on the old one
		int fd = open(opts.frameFile.c_str(), O_RDWR | O_CREAT, 0600);
		if(fd >= 0 && ftruncate(fd, sizeof(TreeShm)) == 0) {
			p = mmap(0, sizeof(TreeShm), PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
		}
		if(p == MAP_FAILED) fprintf(stderr, "treesim: cannot use frame file '%s', not publishing\n",
		                            opts.frameFile.c_str());
		if(fd >= 0) close(fd);   //The mapping keeps the file
	}
	if(p == MAP_FAILED) p = mmap(0, sizeof(TreeShm), PROT_READ | PROT_WRITE, MAP_SHARED | MAP_ANON, -1, 0);
	if(p == MAP_FAILED) { perror("treesim: mmap"); exit(1); }
	shm = (TreeShm*) p;
	slots = shm->slot;

	//A file left over from an earlier run may hold anything: unclaim it, initialise it, and
	//only then claim it again, so a reader never sees a half-built region as valid
	__atomic_store_n(&shm->magic, 0u, __ATOMIC_RELEASE);
	shm->version = TREESHM_VERSION;
	shm->trees = (uint32_t) opts.trees;
	shm->leds = TREESHM_LEDS;
	shm->heartbeat = nowSeconds();
	memset(shm->slot, 0, sizeof(shm->slot));
	for(int i = 0; i < TREESHM_MAX; i++) slots[i].index = slots[i].count = -1;
	__atomic_store_n(&shm->magic, TREESHM_MAGIC, __ATOMIC_RELEASE);
}

//10Hz, for a reader with a sub-second staleness threshold, as in ledsim
void beat() {
	static double last = 0;
	double now = nowSeconds();
	if(now - last < 0.1) return;
	last = now;
	shm->heartbeat = now;
}

void setProcess(int i, uint32_t state) {
	__atomic_store_n(&slots[i].process, state, __ATOMIC_RELEASE);
	if(state == TREESHM_DEAD) __atomic_store_n(&slots[i].connected, 0u, __ATOMIC_RELEASE);
}

//-------------------------------------------------------------------------------------------------
// Child side. Only ever runs in a forked child; `me` is its slot.

Slot* me = 0;
int child_keys = -1;
int child_serial = -1;

void childText(const char* data, size_t len) {
	//The same rule tree_main.cpp applies: i, then two two-digit fields
	if(len >= 5 && data[0] == 'i') {
		bool digits = true;
		for(int i = 1; i < 5; i++) if(data[i] < '0' || data[i] > '9') digits = false;
		if(digits) {
			me->index = (data[1] - '0') * 10 + (data[2] - '0');
			me->count = (data[3] - '0') * 10 + (data[4] - '0');
		}
	}
	size_t n = len < sizeof(me->last) - 1 ? len : sizeof(me->last) - 1;
	memcpy(me->last, data, n);
	me->last[n] = 0;
}

[[noreturn]] void runTree(int tree, const std::vector<int>& inherited, int keys, int serial) {
	//Every other tree's pipes were inherited too. They must go, or a sibling would hold this
	//tree's key pipe open and it would never see the parent exit.
	for(int fd : inherited) if(fd != keys && fd != serial) close(fd);

	//Anything the firmware or the shims print, by any route, ends up in the serial pane. The
	//pipe is not the terminal, so it can be made non-blocking: a parent that falls behind
	//costs serial output, never animation frames.
	dup2(keys, STDIN_FILENO);
	dup2(serial, STDOUT_FILENO);
	dup2(serial, STDERR_FILENO);
	close(keys);
	close(serial);
	child_keys = STDIN_FILENO;
	child_serial = STDOUT_FILENO;
	fcntl(child_serial, F_SETFL, fcntl(child_serial, F_GETFL) | O_NONBLOCK);
	signal(SIGPIPE, SIG_DFL);
	signal(SIGINT, SIG_DFL);   //The parent's handlers only set its own quit flag
	signal(SIGTERM, SIG_DFL);

	me = &slots[tree];   //Reset by the parent before the fork

	//A locally administered MAC, so the id is 5100 followed by the tree number, and the
	//server's id order is the order they are drawn in
	const uint8_t mac[6] = {0x02, 0x00, 0x00, 0x51, 0x00, (uint8_t) (tree + 1)};
	sim_set_mac(mac);
	//tree_init() seeds random() from esp_random(). Every child must get a different seed,
	//or all the trees would twinkle in lockstep.
	sim_set_entropy(opts.seed ? (uint32_t) (opts.seed * 1000003u + tree)
	                          : (uint32_t) time(0) ^ ((uint32_t) getpid() << 12) ^ (uint32_t) tree);
	sim_websocket_set_uri(opts.uri.c_str());
	sim_websocket_set_text_hook(childText);

	setup();
	while(true) {
		loop();
		__atomic_store_n(&me->connected, sim_websocket_is_connected() ? 1u : 0u, __ATOMIC_RELAXED);
		std::this_thread::sleep_for(std::chrono::milliseconds(1));
	}
}

//-------------------------------------------------------------------------------------------------
// Parent side: the trees as processes

enum TreeState { DEAD, RUNNING, FROZEN };

struct Tree {
	pid_t pid = -1;
	TreeState state = DEAD;
	int keys = -1;             //Write end of the child's stdin
	int serial = -1;           //Read end of the child's stdout
	std::string partial;       //Serial output not yet ended by a newline
	char id[8];
};

Tree trees[MAX_TREES];

std::vector<int> openFds() {
	std::vector<int> fds;
	for(int i = 0; i < opts.trees; i++) {
		if(trees[i].keys >= 0) fds.push_back(trees[i].keys);
		if(trees[i].serial >= 0) fds.push_back(trees[i].serial);
	}
	return fds;
}

void closeTreeFds(Tree& t) {
	if(t.keys >= 0) close(t.keys);
	if(t.serial >= 0) close(t.serial);
	t.keys = t.serial = -1;
}

void serialLine(int tree, const std::string& line);

bool spawn(int i) {
	Tree& t = trees[i];
	if(t.state != DEAD) return false;
	closeTreeFds(t);

	int keys[2], serial[2];
	if(pipe(keys) != 0) return false;
	if(pipe(serial) != 0) { close(keys[0]); close(keys[1]); return false; }

	//Everything the child owns starts afresh, as on a board that has just booted. `seq` is
	//left alone so that it stays even and only ever increases.
	Slot& s = slots[i];
	s.frames = 0;
	s.index = s.count = -1;
	s.connected = 0;
	memset(s.rgb, 0, sizeof(s.rgb));
	memset(s.last, 0, sizeof(s.last));
	snprintf(s.id, sizeof(s.id), "%s", t.id);

	std::vector<int> inherited = openFds();
	inherited.push_back(keys[1]);
	inherited.push_back(serial[0]);

	fflush(stdout);
	pid_t pid = fork();
	if(pid < 0) {
		close(keys[0]); close(keys[1]); close(serial[0]); close(serial[1]);
		return false;
	}
	if(pid == 0) runTree(i, inherited, keys[0], serial[1]);

	close(keys[0]);
	close(serial[1]);
	t.pid = pid;
	t.state = RUNNING;
	setProcess(i, TREESHM_RUNNING);
	t.keys = keys[1];
	t.serial = serial[0];
	t.partial.clear();
	fcntl(t.keys, F_SETFL, fcntl(t.keys, F_GETFL) | O_NONBLOCK);
	fcntl(t.serial, F_SETFL, fcntl(t.serial, F_GETFL) | O_NONBLOCK);
	return true;
}

void stopTree(int i) {
	Tree& t = trees[i];
	if(t.state == DEAD) return;
	kill(t.pid, SIGKILL);
	//SIGKILL is delivered to a stopped process too, but it is reaped sooner if it can run
	if(t.state == FROZEN) kill(t.pid, SIGCONT);
}

void toggleFreeze(int i) {
	Tree& t = trees[i];
	if(t.state == RUNNING) { kill(t.pid, SIGSTOP); t.state = FROZEN; setProcess(i, TREESHM_FROZEN); }
	else if(t.state == FROZEN) { kill(t.pid, SIGCONT); t.state = RUNNING; setProcess(i, TREESHM_RUNNING); }
}

void reap() {
	int status;
	pid_t pid;
	while((pid = waitpid(-1, &status, WNOHANG)) > 0) {
		for(int i = 0; i < opts.trees; i++) {
			if(trees[i].pid != pid) continue;
			trees[i].state = DEAD;
			trees[i].pid = -1;
			setProcess(i, TREESHM_DEAD);
			if(WIFSIGNALED(status) && WTERMSIG(status) != SIGKILL) {
				char buf[64];
				snprintf(buf, sizeof(buf), "\x1b[31m(died on signal %d)\x1b[0m", WTERMSIG(status));
				serialLine(i, buf);
			}
		}
	}
}

//Consistent copy of a slot's ring, or false if the child was mid-write throughout
bool readRing(int i, uint8_t* rgb, uint64_t* frames) {
	Slot& s = slots[i];
	for(int attempt = 0; attempt < 8; attempt++) {
		uint32_t before = __atomic_load_n(&s.seq, __ATOMIC_ACQUIRE);
		if(before & 1) continue;
		memcpy(rgb, s.rgb, sizeof(s.rgb));
		*frames = s.frames;
		std::atomic_thread_fence(std::memory_order_acquire);
		if(__atomic_load_n(&s.seq, __ATOMIC_RELAXED) == before) return true;
	}
	return false;
}

//-------------------------------------------------------------------------------------------------
// Colour.
//
// The bytes sent to a WS2812 set its PWM duty, so they are linear in light: tree_tick() has
// already gamma corrected them for the eye. A monitor instead treats bytes as sRGB, which is
// strongly non-linear, so drawn as they are the wire values look far darker than the tree does
// (a byte of 32 is an eighth of full light, which an LED shows as clearly lit and a monitor as
// near black). Encoding the light level as sRGB puts it on the screen at the brightness it has
// on the desk. --wire draws the raw bytes instead, for checking the values themselves.

uint8_t to_screen[256];

void buildColourTable() {
	for(int i = 0; i < 256; i++) {
		double l = i / 255.0;
		double v = l <= 0.0031308 ? 12.92 * l : 1.055 * pow(l, 1 / 2.4) - 0.055;
		to_screen[i] = (uint8_t) lround(v * 255);
	}
}

//-------------------------------------------------------------------------------------------------
// Terminal

void emit(const char* data, size_t len) {
	size_t written = 0;
	while(written < len) {
		ssize_t n = write(STDOUT_FILENO, data + written, len - written);
		if(n <= 0) return;
		written += (size_t) n;
	}
}
void emit(const std::string& s) { emit(s.data(), s.size()); }

struct termios saved_termios;
bool termios_saved = false;
bool terminal_restored = false;
volatile sig_atomic_t quit = false;

void restoreTerminal() {
	if(terminal_restored) return;
	terminal_restored = true;
	if(termios_saved) tcsetattr(STDIN_FILENO, TCSANOW, &saved_termios);
	if(!opts.plain) emit(std::string("\x1b[?25h\x1b[?1049l"));
}

void onSignal(int) { quit = true; }

void setupTerminal() {
	if(opts.plain) return;
	if(isatty(STDIN_FILENO) && tcgetattr(STDIN_FILENO, &saved_termios) == 0) {
		termios_saved = true;
		struct termios raw = saved_termios;
		raw.c_lflag &= ~(ICANON | ECHO);   //ISIG left on, so ctrl-C still quits
		raw.c_cc[VMIN] = 0;
		raw.c_cc[VTIME] = 0;
		tcsetattr(STDIN_FILENO, TCSANOW, &raw);
	}
	emit(std::string("\x1b[?1049h\x1b[?25l\x1b[2J"));
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

size_t visibleLen(const std::string& s) {
	size_t n = 0;
	for(size_t i = 0; i < s.size(); i++) {
		if(s[i] == '\x1b') {
			while(i < s.size() && !isalpha((unsigned char) s[i])) i++;
		} else if((s[i] & 0xc0) != 0x80) {
			n++;
		}
	}
	return n;
}

//-------------------------------------------------------------------------------------------------
// Serial pane

std::deque<std::string> log_lines;
const size_t LOG_ROWS = 10;

const char* treeColour(int i) {
	static const char* c[] = {"36", "33", "35", "32", "34", "91", "96", "93"};
	return c[i % 8];
}

void serialLine(int tree, const std::string& line) {
	char prefix[32];
	snprintf(prefix, sizeof(prefix), "\x1b[%sm%2d\x1b[0m ", treeColour(tree), tree);
	if(opts.plain) {
		printf("%2d %s\n", tree, line.c_str());
		fflush(stdout);
		return;
	}
	log_lines.push_back(prefix + line);
	while(log_lines.size() > LOG_ROWS) log_lines.pop_front();
}

void drainSerial() {
	char buf[1024];
	for(int i = 0; i < opts.trees; i++) {
		Tree& t = trees[i];
		if(t.serial < 0) continue;
		ssize_t n;
		while((n = read(t.serial, buf, sizeof(buf))) > 0) {
			for(ssize_t j = 0; j < n; j++) {
				if(buf[j] == '\n') { serialLine(i, t.partial); t.partial.clear(); }
				else if(buf[j] != '\r' && t.partial.size() < 200) t.partial += buf[j];
			}
		}
		if(n == 0) { close(t.serial); t.serial = -1; }  //The child has gone
	}
}

//-------------------------------------------------------------------------------------------------
// Keys. Tab picks which tree they go to; X, S and Z are the simulator's own, everything
// else is passed to the firmware's debug console in tree_main.cpp.

int target = -1;   //-1 for every tree

void forEachTarget(void (*f)(int)) {
	for(int i = 0; i < opts.trees; i++) if(target < 0 || target == i) f(i);
}

void handleKey(char c) {
	switch(c) {
		case '\t': target = target + 1 >= opts.trees ? -1 : target + 1; return;
		case 'X': forEachTarget(stopTree); return;
		case 'S': forEachTarget([](int i) { spawn(i); }); return;
		case 'Z': forEachTarget(toggleFreeze); return;
	}
	for(int i = 0; i < opts.trees; i++) {
		if((target < 0 || target == i) && trees[i].state == RUNNING && trees[i].keys >= 0) {
			if(write(trees[i].keys, &c, 1) < 0) {} //A full or closed pipe just loses the key
		}
	}
}

void readKeys() {
	if(opts.plain) return;
	struct pollfd p;
	p.fd = STDIN_FILENO;
	p.events = POLLIN;
	while(poll(&p, 1, 0) > 0) {
		char c;
		if(read(STDIN_FILENO, &c, 1) != 1) return;
		handleKey(c);
	}
}

//-------------------------------------------------------------------------------------------------
// Rendering. Each tree is its ring of 8 drawn round a 3x3 square: LED 0 at the top and the
// rest clockwise, as on the board.

const int CELL = 12;        //Columns per tree, including the gap after it
const int RING_ROWS = 3;
// For each LED, its row and column in the 3x3 square
const int RING_POS[TREE_NUM_LEDS][2] = {
	{0, 1}, {0, 2}, {1, 2}, {2, 2}, {2, 1}, {2, 0}, {1, 0}, {0, 0}
};
static_assert(TREE_NUM_LEDS == 8, "RING_POS is laid out for an 8 LED ring");

std::string pixel(const uint8_t* rgb, bool alive) {
	char buf[40];
	uint8_t r = rgb[0], g = rgb[1], b = rgb[2];
	if(!opts.wire) { r = to_screen[r]; g = to_screen[g]; b = to_screen[b]; }
	if(!alive) { r /= 3; g /= 3; b /= 3; }
	//An unlit LED is drawn as a dim outline so the ring stays visible
	if(r == 0 && g == 0 && b == 0) return "\x1b[38;2;60;60;60m░░";
	snprintf(buf, sizeof(buf), "\x1b[38;2;%u;%u;%um██", r, g, b);
	return buf;
}

std::chrono::steady_clock::time_point last_fps_sample;
uint64_t frames_at_sample[MAX_TREES];
double fps[MAX_TREES];

void sampleFps() {
	const auto now = std::chrono::steady_clock::now();
	double dt = std::chrono::duration<double>(now - last_fps_sample).count();
	if(dt < 1.0) return;
	for(int i = 0; i < opts.trees; i++) {
		uint64_t f = slots[i].frames;
		fps[i] = (f - frames_at_sample[i]) / dt;
		frames_at_sample[i] = f;
	}
	last_fps_sample = now;
}

void render() {
	int rows = 0, cols = 0;
	terminalSize(&rows, &cols);
	static int last_rows = 0, last_cols = 0;
	if(rows != last_rows || cols != last_cols) {
		last_rows = rows;
		last_cols = cols;
		emit(std::string("\x1b[2J"));
	}

	std::vector<std::string> lines;
	char buf[256];

	int live = 0;
	const char* last = "";
	for(int i = 0; i < opts.trees; i++) {
		if(trees[i].state != DEAD && slots[i].connected) {
			live++;
			if(!*last) last = slots[i].last;
		}
	}
	char tgt[16];
	if(target < 0) snprintf(tgt, sizeof(tgt), "all");
	else snprintf(tgt, sizeof(tgt), "%d", target);
	snprintf(buf, sizeof(buf), "\x1b[1m treesim\x1b[0m  %d of %d connected  keys to: \x1b[1m%s\x1b[0m"
	         "  last '%s'  %s", live, opts.trees, tgt, last, opts.wire ? "wire values" : "as seen");
	lines.push_back(buf);
	lines.push_back("");

	const int perRow = (cols - 1) / CELL < 1 ? 1 : (cols - 1) / CELL;
	for(int first = 0; first < opts.trees; first += perRow) {
		const int end = first + perRow < opts.trees ? first + perRow : opts.trees;
		std::vector<std::string> band(RING_ROWS + 2, " ");
		for(int i = first; i < end; i++) {
			uint8_t rgb[TREE_NUM_LEDS * 3];
			uint64_t frames;
			if(!readRing(i, rgb, &frames)) memset(rgb, 0, sizeof(rgb));
			const bool alive = trees[i].state == RUNNING;

			std::string cell[RING_ROWS];
			for(int r = 0; r < RING_ROWS; r++) cell[r] = "  ";
			for(int r = 0; r < RING_ROWS; r++) {
				for(int c = 0; c < 3; c++) {
					int led = -1;
					for(int k = 0; k < TREE_NUM_LEDS; k++) {
						if(RING_POS[k][0] == r && RING_POS[k][1] == c) led = k;
					}
					cell[r] += led < 0 ? "  " : pixel(rgb + led * 3, alive);
					if(c < 2) cell[r] += " ";
				}
				cell[r] += "\x1b[0m  ";
			}
			for(int r = 0; r < RING_ROWS; r++) band[r] += cell[r];

			//Label: tree number and id, then what it is doing
			const bool selected = target == i;
			snprintf(buf, sizeof(buf), "%s\x1b[%sm%2d %-6s\x1b[0m   ", selected ? "\x1b[7m" : "",
			         treeColour(i), i, trees[i].id);
			band[RING_ROWS] += buf;

			const Slot& s = slots[i];
			if(trees[i].state == DEAD) snprintf(buf, sizeof(buf), "\x1b[90m%-11s\x1b[0m", "dead");
			else if(trees[i].state == FROZEN) snprintf(buf, sizeof(buf), "\x1b[33m%-11s\x1b[0m", "frozen");
			else if(!s.connected) snprintf(buf, sizeof(buf), "\x1b[31m%-11s\x1b[0m", "waiting");
			else if(s.index < 0) snprintf(buf, sizeof(buf), "\x1b[32m%-11s\x1b[0m", "no place");
			else {
				char place[16];
				snprintf(place, sizeof(place), "%d of %d", s.index, s.count);
				snprintf(buf, sizeof(buf), "\x1b[32m%-11s\x1b[0m", place);
			}
			band[RING_ROWS + 1] += buf;
			band[RING_ROWS + 1] += " ";
		}
		for(auto& l : band) lines.push_back(l);
		lines.push_back("");
	}

	//Per-tree frame rates, on one line
	std::string rates = "\x1b[90m fps";
	for(int i = 0; i < opts.trees; i++) {
		snprintf(buf, sizeof(buf), " %d:%.0f", i, trees[i].state == RUNNING ? fps[i] : 0.0);
		rates += buf;
	}
	rates += "\x1b[0m";
	if(visibleLen(rates) <= (size_t) cols) lines.push_back(rates);

	const int spare = rows - (int) lines.size();
	if(spare >= 4) {
		const size_t room = (size_t) (spare - 3);
		const size_t shown = room < LOG_ROWS ? room : LOG_ROWS;
		lines.push_back("");
		lines.push_back("\x1b[90m--- serial ---\x1b[0m");
		const size_t skip = log_lines.size() > shown ? log_lines.size() - shown : 0;
		for(size_t i = 0; i < shown; i++) {
			lines.push_back(skip + i < log_lines.size() ? log_lines[skip + i] : "");
		}
		const std::string footer =
			"\x1b[90mTab: pick tree  X kill  S start  Z freeze/thaw  "
			"firmware keys: 0-5 b p r g k w = - i n  ctrl-C quits\x1b[0m";
		lines.push_back(visibleLen(footer) <= (size_t) cols ? footer : "");
	}

	std::string out = "\x1b[H";
	const size_t limit = lines.size() < (size_t) rows ? lines.size() : (size_t) rows;
	for(size_t i = 0; i < limit; i++) {
		out += lines[i];
		out += "\x1b[K";
		if(i + 1 < limit) out += "\n";
	}
	out += "\x1b[J";
	emit(out);
}

} //namespace

//-------------------------------------------------------------------------------------------------
// Hooks called by the shims. In treesim these only ever run in a child.

void sim_serial_out(const char* text, size_t len) {
	if(child_serial >= 0 && write(child_serial, text, len) < 0) {} //Full pipe: dropped
}

int sim_serial_available() {
	struct pollfd p;
	p.fd = child_keys;
	p.events = POLLIN;
	if(poll(&p, 1, 0) <= 0) return 0;
	if(p.revents & POLLIN) return 1;
	//Hung up with nothing left to read: the parent has gone, so the tree goes too
	if(p.revents & (POLLHUP | POLLERR)) _exit(0);
	return 0;
}

int sim_serial_read() {
	char c;
	ssize_t n = read(child_keys, &c, 1);
	if(n == 1) return (unsigned char) c;
	if(n == 0) _exit(0);
	return -1;
}

void sim_leds_show(const RgbColor* pixels, uint16_t count) {
	if(!me) return;
	const uint16_t n = count < TREE_NUM_LEDS ? count : TREE_NUM_LEDS;
	__atomic_store_n(&me->seq, me->seq + 1, __ATOMIC_RELAXED);   //Odd: writing
	std::atomic_thread_fence(std::memory_order_release);
	for(uint16_t i = 0; i < n; i++) {
		me->rgb[i * 3 + 0] = pixels[i].R;
		me->rgb[i * 3 + 1] = pixels[i].G;
		me->rgb[i * 3 + 2] = pixels[i].B;
	}
	me->frames++;
	__atomic_store_n(&me->seq, me->seq + 1, __ATOMIC_RELEASE);   //Even: settled
}

//-------------------------------------------------------------------------------------------------

static void usage() {
	fprintf(stderr,
		"treesim - runs several desk trees' firmware on the host and draws them in the terminal\n\n"
		"  -n <trees>               how many trees (default 4, at most %d)\n"
		"  --uri <ws://host:port/>  LED websocket to connect to (default ws://127.0.0.1:8092/)\n"
		"  --wire                   draw the bytes sent to the LEDs, rather than how bright\n"
		"                           the LEDs look\n"
		"  --plain                  no alternate screen or raw input; serial goes to stdout\n"
		"  --seed <n>               fixed random seed, for reproducible animations\n"
		"  --render-hz <n>          terminal redraw rate (default 30)\n"
		"  --frame-file <path>      shared frame file for other viewers\n"
		"                           (default " TREESHM_DEFAULT_PATH ")\n"
		"  --no-frame-file          do not publish frames\n"
		"  --help\n", MAX_TREES);
}

int main(int argc, char** argv) {
	for(int i = 1; i < argc; i++) {
		std::string a = argv[i];
		if((a == "-n" || a == "--trees") && i + 1 < argc) opts.trees = atoi(argv[++i]);
		else if(a == "--uri" && i + 1 < argc) opts.uri = argv[++i];
		else if(a == "--wire") opts.wire = true;
		else if(a == "--plain") opts.plain = true;
		else if(a == "--seed" && i + 1 < argc) opts.seed = strtoul(argv[++i], 0, 10);
		else if(a == "--render-hz" && i + 1 < argc) opts.renderHz = atoi(argv[++i]);
		else if(a == "--frame-file" && i + 1 < argc) opts.frameFile = argv[++i];
		else if(a == "--no-frame-file") opts.frameFile.clear();
		else { usage(); return a == "--help" ? 0 : 1; }
	}
	if(opts.trees < 1 || opts.trees > MAX_TREES) { usage(); return 1; }
	if(opts.renderHz < 1) opts.renderHz = 1;

	mapShared();
	buildColourTable();
	for(int i = 0; i < opts.trees; i++) {
		snprintf(trees[i].id, sizeof(trees[i].id), "51%04x", i + 1);  //As tree_main.cpp makes it
	}

	signal(SIGINT, onSignal);
	signal(SIGTERM, onSignal);
	signal(SIGPIPE, SIG_IGN);    //Writing a key to a tree that has just died
	setupTerminal();
	atexit(restoreTerminal);

	for(int i = 0; i < opts.trees; i++) {
		if(!spawn(i)) {
			restoreTerminal();
			fprintf(stderr, "treesim: could not start tree %d: %s\n", i, strerror(errno));
			return 1;
		}
	}

	last_fps_sample = std::chrono::steady_clock::now();
	auto last_render = last_fps_sample;
	while(!quit) {
		readKeys();
		drainSerial();
		reap();
		sampleFps();
		beat();
		const auto now = std::chrono::steady_clock::now();
		if(!opts.plain && std::chrono::duration_cast<std::chrono::milliseconds>(now - last_render).count()
		   >= 1000 / opts.renderHz) {
			last_render = now;
			render();
		}
		std::this_thread::sleep_for(std::chrono::milliseconds(5));
	}

	for(int i = 0; i < opts.trees; i++) stopTree(i);
	for(int i = 0; i < opts.trees; i++) if(trees[i].pid > 0) waitpid(trees[i].pid, 0, 0);
	restoreTerminal();
	return 0;
}
