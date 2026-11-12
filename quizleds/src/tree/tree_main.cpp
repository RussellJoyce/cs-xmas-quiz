// Desk tree firmware. Built by its own PlatformIO project in quizleds/tree/. Shares only the top
// of src/ (net.cpp and credentials.h) with the string, whose code is in src/string/.
//
// Protocol. The quiz software sends "lt" + command; the server strips the "lt" and sends the
// command to every tree. All numbers are fixed-width decimal. Team ids tt are 0-based.
//
// Identity (sent by the server, not the quiz software)
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
// Firmware update (the quiz software sends "ltu"; the server adds its firmware port)
//   uPPPPP    - fetch http://<server>:PPPPP/firmware/tree-<chip>.bin, where <server> is the
//               host this tree's websocket connects to and <chip> is e.g. esp32c3. The ring
//               fills blue during the download, then the tree reboots into the new image.
//               If it is already running that image it pulses green; if the update fails,
//               red, and it carries on with the old one.

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
			if(a < 0 || a > 5) {
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

	// Show something while WiFi comes up, so a dead tree is obvious
	tree_ambient(1);
	tree_tick(millis());

	if(!TREE_OFFLINE_MODE) net_begin(hostname, query);
}

// Serial debug keys: 0-5 ambient, b buzz (next team each press), p/r/g pulse, k countdown
// step, w wave, -/= single LED, i identity, n network details, x drop WiFi (to test
// reconnecting)
static void serial_keys() {
	static int team = 0, single = 0, count = 100;
	if(!Serial.available()) return;
	char c = Serial.read();
	if(c >= '0' && c <= '5') { tree_ambient(c - '0'); return; }
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

void loop() {
	static uint32_t next_frame = 0;
	uint32_t now = millis();
	if((int32_t)(now - next_frame) >= 0) {
		tree_tick(now);
		next_frame = now + TREE_MILLIS_PER_FRAME;
	}
	serial_keys();
	if(!TREE_OFFLINE_MODE) net_tick(handle_command);
}
