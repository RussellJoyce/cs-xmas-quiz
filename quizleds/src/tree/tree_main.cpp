// Desk tree firmware. Built by its own PlatformIO project in quizleds/tree/. Shares only the top
// of src/ (net.cpp and credentials.h) with the string, whose code is in src/string/.
//
// Transport. A tree takes commands by USB serial or by WiFi, never both at once.
//   USB serial: a computer on the tree's USB port sends each command as a line, ">" +
//     command + "\n", e.g. ">b03\n". Its first should be the hello, ">h\n", which turns
//     WiFi off for good (until the tree restarts) and is answered with one line
//       <tree <id> <chip> <build date and time>
//     e.g. "<tree d62534 esp32c3 Nov 25 2026 14:02:11". The hello can be sent again at any
//     time, as a check that the tree is there; each one is answered. Every other line the tree
//     writes is debug output, and none of it starts with "<". Characters outside a ">" line
//     are the debug keys (below), so a serial monitor works as before.
//   WiFi: the quiz software sends "lt" + command; the node server strips the "lt" and sends
//     the command to every tree over its websocket. A tree only starts WiFi if no hello has
//     come TREE_SERIAL_GRACE_MS after boot, so one on a USB charger still joins the quiz.
//
// Protocol. All numbers are fixed-width decimal. Team ids tt are 0-based.
//
// Identity (sent by the node server over WiFi, or by the computer over serial)
//   iNNCC     - this tree is number NN of CC connected. Staggered effects start NN steps
//               late, and ambient animations are offset by NN/CC so that they roll across
//               the room. Resent to every tree when one joins or leaves.
// Number of team colours
//   ntt       - divide the hue wheel into tt slices for team colours (default 14), as on the
//               string. The server forwards the quiz software's len command here too.
// Brightness
//   gbbb      - global brightness 0-255 (default 128)
// Ambient animation
//   a00 - off
//   a01 - twinkle: festive colours fading in and out
//   a02 - rainbow spinning round the ring
//   a03 - candle flicker
//   a04 - room wave: each tree a single colour, rolling across the trees
//   a05 - chase: a comet circling the ring
//   a06 - Megamas in blocks: three neighbouring LEDs at a time slide to red, green or blue
//   a07 - Megamas trees: each tree all one of those colours. On a steady 1 s beat, a third
//         of the trees change, in turn by tree number
//   Any other id is logged and treated as off.
// Buzz for a team
//   btt       - spin up in team tt's colour, flash, then hold it. Staggered by tree number.
// Solid colours
//   crrrgggbbb - set the tree to an rgb colour, components 0-255
//   ttt       - set the tree to team tt's colour
// Countdown
//   kppp      - ring filled to ppp percent (0-100), green to red; flashes red at 0
// Pulses: fade in and out over whatever the tree was showing, then leave it showing
//   p00 - white, p01 - red, p02 - green. Any other value pulses white.
//   qtt       - slow pulse of team tt's colour
//   qTT       - where TT >= 50, quick pulse of team TT-50's colour
// Wave
//   wsss      - white flash, tree NN firing NN * sss ms after the command: a ripple across
//               the trees in order
// Firmware update, WiFi only (the quiz software sends "ltu"; the server adds its firmware port)
//   uPPPPP    - fetch http://<server>:PPPPP/firmware/tree-<chip>.bin, where <server> is the
//               host this tree's websocket connects to and <chip> is e.g. esp32c3. The ring
//               fills blue during the download, then the tree reboots into the new image.
//               If it is already running that image it pulses green; if the update fails,
//               red, and it carries on with the old one. Over serial there is no WiFi, so it
//               pulses red; flash it by USB instead (pio run -t upload).

#include <Arduino.h>
#include <esp_mac.h>
#include <WiFi.h>
#include <net.h>
#include <ota.h>
#include "tree_settings.h"
#include "tree_anim.h"

static char tree_id[7];          // last three bytes of the MAC, e.g. "d62534"
static char hostname[20];        // "quiztree-d62534"
static char query[16];           // "tree=d62534"
static bool serial_host = false; // a computer has said hello over USB; WiFi is off

// A fixed-width decimal field, or -1 if it is short or not all digits
static int field(const char *data, int length, int start, int width) {
	if(start + width > length) return -1;
	int v = 0;
	for(int i = start; i < start + width; i++) {
		if(data[i] < '0' || data[i] > '9') return -1;
		v = v * 10 + (data[i] - '0');
	}
	return v;
}

static void handle_command(char *dat, int len) {
	switch(dat[0]) {
		case 'i': {
			int idx = field(dat, len, 1, 2), cnt = field(dat, len, 3, 2);
			if(idx >= 0 && cnt >= 0) {
				Serial.printf("Tree %d of %d\n", idx, cnt);
				tree_set_identity(idx, cnt);
			}
			break;
		}
		case 'n': {
			int n = field(dat, len, 1, 2);
			if(n > 0) tree_set_team_count(n);
			break;
		}
		case 'g': {
			int b = field(dat, len, 1, 3);
			if(b >= 0 && b <= 255) tree_set_brightness(b);
			break;
		}
		case 'a': {
			int a = field(dat, len, 1, 2);
			if(a < 0 || a > 7) {
				Serial.printf("Unknown animation %.*s\n", len - 1, dat + 1);
				a = 0;
			}
			Serial.printf("Anim %d\n", a);
			tree_ambient(a);
			break;
		}
		case 'b': {
			int t = field(dat, len, 1, 2);
			if(t >= 0) { Serial.printf("Buzz %d\n", t); tree_buzz(t); }
			break;
		}
		case 'c': {
			int r = field(dat, len, 1, 3), g = field(dat, len, 4, 3), b = field(dat, len, 7, 3);
			if(r >= 0 && g >= 0 && b >= 0 && r <= 255 && g <= 255 && b <= 255)
				tree_solid(RgbColor(r, g, b));
			break;
		}
		case 't': {
			int t = field(dat, len, 1, 2);
			if(t >= 0) tree_team_colour(t);
			break;
		}
		case 'k': {
			int p = field(dat, len, 1, 3);
			if(p >= 0) tree_countdown(p);
			break;
		}
		case 'p': {
			int p = field(dat, len, 1, 2);
			tree_pulse_colour(p);
			break;
		}
		case 'q': {
			int q = field(dat, len, 1, 2);
			if(q >= 0) tree_pulse_team(q);
			break;
		}
		case 'w': {
			int s = field(dat, len, 1, 3);
			if(s >= 0) tree_wave(s);
			break;
		}
		case 'u': {
			if(!net_running()) {
				Serial.println("No WiFi, so no update");
				tree_pulse_colour(1);
				break;
			}
			int port = field(dat, len, 1, 5);
			char host[64];
			if(port <= 0 || port > 65535 || !net_server_host(host, sizeof(host))) break;
			tree_show_progress(0, 1);
			ota_result r = ota_update(host, port, "tree-" CONFIG_IDF_TARGET, tree_show_progress);
			tree_pulse_colour(r == OTA_UP_TO_DATE ? 2 : 1);
			break;
		}
		default:
			Serial.printf("Tree command %c\n", dat[0]);
			break;
	}
}

static void make_identity() {
	uint8_t mac[6];
	esp_read_mac(mac, ESP_MAC_WIFI_STA);
	snprintf(tree_id, sizeof(tree_id), "%02x%02x%02x", mac[3], mac[4], mac[5]);
	snprintf(hostname, sizeof(hostname), "quiztree-%s", tree_id);
	snprintf(query, sizeof(query), "tree=%s", tree_id);
}

void setup() {
	// No while(!Serial): on the C3's native USB that waits for a computer, and a tree on a
	// USB charger would never boot
	Serial.begin(115200);
	tree_init();
	make_identity();
	Serial.printf("Tree %s, built %s %s\n", tree_id, __DATE__, __TIME__);

	// One frame of the twinkle, held still until WiFi is joined or a computer says hello
	// (loop()), so a tree that is on but connected to nothing is obvious
	tree_ambient(1);
	tree_tick(millis());
	// WiFi waits for TREE_SERIAL_GRACE_MS, in loop(), in case a computer says hello
}

// The hello: a computer has this tree on USB, so it takes the tree over from WiFi
static void serial_hello() {
	if(!serial_host) {
		serial_host = true;
		net_end();
		Serial.println("Serial host");
	}
	Serial.printf("<tree %s %s %s %s\n", tree_id, CONFIG_IDF_TARGET, __DATE__, __TIME__);
}

static void serial_line(char *dat, int len) {
	if(len == 0) return;
	if(dat[0] == 'h') serial_hello();
	else handle_command(dat, len);
}

// Serial debug keys: 0-7 ambient, b buzz (next team each press), p/r/g pulse, k countdown
// step, w wave, -/= single LED, i identity, n network details, x drop WiFi (to test
// rejoining)
static void debug_key(char c) {
	static int team = 0, single = 0, count = 100;
	if(c >= '0' && c <= '7') { tree_ambient(c - '0'); return; }
	switch(c) {
		case 'b': tree_buzz(team); team = (team + 1) % 14; break;
		case 'p': tree_pulse_colour(0); break;
		case 'r': tree_pulse_colour(1); break;
		case 'g': tree_pulse_colour(2); break;
		case 'k': count = count <= 0 ? 100 : count - 10; tree_countdown(count); break;
		case 'w': tree_wave(100); break;
		case '=': single = (single + 1) % 8; tree_single(single); break;
		case '-': single = (single + 7) % 8; tree_single(single); break;
		case 'i': Serial.printf("Tree %s (%s)\n", tree_id, hostname); break;
		case 'n': net_print_details(); break;
		case 'x': Serial.println("Dropping WiFi"); WiFi.disconnect(); break;
		default: Serial.print('#'); break;
	}
}

// Everything that has arrived over serial: ">" lines are commands, anything else a debug key.
// A line longer than a websocket command (COMMAND_MAX_LEN in net.cpp) is dropped whole.
static void serial_input() {
	static char line[64];
	static int line_len = -1;        // -1 outside a ">" line
	static bool overflow = false;
	while(Serial.available()) {
		int c = Serial.read();
		if(c < 0) break;
		if(line_len >= 0) {
			if(c == '\n' || c == '\r') {
				if(overflow) Serial.println("Serial line too long, dropped");
				else serial_line(line, line_len);
				line_len = -1;
			} else if(line_len < (int)sizeof(line)) {
				line[line_len++] = c;
			} else {
				overflow = true;
			}
		} else if(c == '>') {
			line_len = 0;
			overflow = false;
		} else if(c != '\n' && c != '\r') {
			debug_key(c);
		}
	}
}

void loop() {
	static uint32_t next_frame = 0;
	uint32_t now = millis();
	bool live = TREE_OFFLINE_MODE || serial_host || net_has_joined();
	if(live && (int32_t)(now - next_frame) >= 0) {
		tree_tick(now);
		next_frame = now + TREE_MILLIS_PER_FRAME;
	}
	serial_input();
	if(!TREE_OFFLINE_MODE && !serial_host && !net_running() && now >= TREE_SERIAL_GRACE_MS) {
		net_begin(hostname, query);
	}
	// Also drains anything the websocket queued before a hello turned WiFi off
	net_tick(handle_command);
}
