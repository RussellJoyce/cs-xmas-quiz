#include "tree_anim.h"
#include "tree_settings.h"
#include "tree_ring.h"
#include <math.h>

#define N TREE_NUM_LEDS

static NeoGamma<NeoGammaTableMethod> gamma_table;

static int my_index = 0, tree_count = 1;
static int team_hue_slices = TREE_DEFAULT_TEAM_HUE_SLICES;
static uint8_t brightness = TREE_DEFAULT_BRIGHTNESS;

typedef enum { B_AMBIENT, B_SOLID, B_BUZZ, B_COUNTDOWN, B_SINGLE } BaseMode;
typedef enum { O_NONE, O_PULSE, O_WAVE } OverlayMode;

static BaseMode base_mode = B_AMBIENT;
static int ambient_id = 1;
static RgbColor solid_col(0);
static float buzz_hue = 0;
static uint32_t base_start = 0;   // when the base layer started; may be in the future (stagger)
static int countdown = 100;
static int single_led = 0;

static OverlayMode overlay = O_NONE;
static RgbColor overlay_col(0);
static uint32_t overlay_start = 0; // may be in the future (stagger)
static uint32_t overlay_decay = 0;

static RgbColor frame[N];
static RgbColor out[N];      // frame after gamma and brightness

//-------------------------------------------------------------------------------------------------

static float frand() { return (float)random(0, 10000) / 10000.0f; }
static float fwrap(float x) { return x - floorf(x); }
static float clamp01(float x) { return x < 0 ? 0 : (x > 1 ? 1 : x); }

static RgbColor hsb(float h, float s, float b) {
	return RgbColor(HsbColor(fwrap(h), clamp01(s), clamp01(b)));
}

static float team_hue(int t) {
	// Same hue as team_col() on the string and Utils.teamHue in the quiz software
	return fwrap((float)t / team_hue_slices);
}

// Where this tree sits in the room, 0 to just under 1
static float phase() {
	return tree_count > 0 ? (float)my_index / tree_count : 0;
}

//-------------------------------------------------------------------------------------------------
// Ambient animations

// Old-fashioned festive palette: red, green, gold, blue, warm white
static const float palette_h[] = { 0.0f, 0.33f, 0.11f, 0.62f, 0.08f };
static const float palette_s[] = { 1.0f, 1.0f,  1.0f,  1.0f,  0.35f };
#define PALETTE_LEN 5

struct Twinkle { float phase, speed; uint8_t col; };
static Twinkle twinkles[N];

static void ambient_twinkle(uint32_t dt) {
	for(int i = 0; i < N; i++) {
		Twinkle &t = twinkles[i];
		t.phase += t.speed * dt;
		if(t.phase >= 1.0f) {
			t.phase -= 1.0f;
			t.col = random(0, PALETTE_LEN);
			t.speed = 0.0004f + frand() * 0.0008f;
		}
		float w = 0.5f - 0.5f * cosf(t.phase * 2 * PI);
		frame[i] = hsb(palette_h[t.col], palette_s[t.col], 0.12f + 0.88f * w * w);
	}
}

static void ambient_rainbow(uint32_t now) {
	float spin = now * 0.00025f;
	for(int i = 0; i < N; i++)
		frame[i] = hsb((float)i / N + spin + phase(), 1, 1);
}

static float candle_level[N], candle_target[N];

static void ambient_candle() {
	for(int i = 0; i < N; i++) {
		if(random(0, 100) < 8) candle_target[i] = 0.35f + 0.65f * frand();
		candle_level[i] += (candle_target[i] - candle_level[i]) * 0.25f;
		frame[i] = hsb(0.07f + 0.02f * candle_level[i], 1.0f, candle_level[i]);
	}
}

// The whole tree one colour, with hue and brightness out of phase between trees, so that
// colour and light roll across the room
static void ambient_roomwave(uint32_t now) {
	float h = now * 0.00006f + phase();
	float b = 0.55f + 0.45f * sinf(2 * PI * (now * 0.0004f - phase()));
	for(int i = 0; i < N; i++) frame[i] = hsb(h, 1, b);
}

static void ambient_chase(uint32_t now) {
	float head = fwrap(now * 0.0006f + phase()) * N;
	float h = now * 0.00004f + phase();
	for(int i = 0; i < N; i++) {
		float behind = fmodf(head - i + N, N);
		frame[i] = hsb(h + behind * 0.03f, 1, powf(0.5f, behind));
	}
}

// Megamas in blocks: as the string's Megamas, LEDs are set to red, green or blue and slide
// round the hue wheel to it (so red to green passes through orange and yellow), but three
// neighbours change together. On eight LEDs that reads as a few bold patches of colour
// rather than a scatter.
#define MEGA_BLOCK 3
#define MEGA_EVERY_MS 450         // a new block this often
#define MEGA_HUE_PER_MS 0.0008f   // slide speed: the string's 0.01 per 13 ms frame
static const float mega_hues[] = { 0.0f, 0.3f, 0.6f };
static float mega_hue[N], mega_target[N];
static uint32_t mega_next = 0;

static void ambient_megamas(uint32_t now, uint32_t dt) {
	if((int32_t)(now - mega_next) >= 0) {
		mega_next = now + MEGA_EVERY_MS;
		float h = mega_hues[random(0, 3)];
		int start = random(0, N);
		for(int k = 0; k < MEGA_BLOCK; k++) mega_target[(start + k) % N] = h;
	}
	float step = MEGA_HUE_PER_MS * dt;
	for(int i = 0; i < N; i++) {
		float d = mega_target[i] - mega_hue[i];
		mega_hue[i] = fabsf(d) <= step ? mega_target[i] : mega_hue[i] + (d > 0 ? step : -step);
		frame[i] = hsb(mega_hue[i], 1, 1);
	}
}

// Megamas trees: the whole tree is one of Megamas' colours, and slides to another. The room
// keeps a steady beat, counted from when the command arrived (the same moment, near enough,
// on every tree), and each tree changes on every MEGATREE_GROUPS'th beat, which beat set by
// its place in the room: so on every beat about a third of the trees change, never all.
#define MEGATREE_BEAT_MS 1000
#define MEGATREE_GROUPS 3
static int32_t mega_beat = -1;

static void ambient_megatree(uint32_t now, uint32_t dt) {
	int32_t beat = (int32_t)(now - base_start) / MEGATREE_BEAT_MS;
	if(beat != mega_beat && beat % MEGATREE_GROUPS == my_index % MEGATREE_GROUPS) {
		// Always a different colour, so that no change is wasted
		float h;
		do { h = mega_hues[random(0, 3)]; } while(h == mega_target[0]);
		for(int i = 0; i < N; i++) mega_target[i] = h;
	}
	mega_beat = beat;
	float step = MEGA_HUE_PER_MS * dt;
	float d = mega_target[0] - mega_hue[0];
	float hue = fabsf(d) <= step ? mega_target[0] : mega_hue[0] + (d > 0 ? step : -step);
	for(int i = 0; i < N; i++) {
		mega_hue[i] = hue;
		frame[i] = hsb(hue, 1, 1);
	}
}

//-------------------------------------------------------------------------------------------------
// Buzz: a comet in the team colour spins up, flashes, and settles on a shimmering solid colour

#define BUZZ_SPIN_MS 700
#define BUZZ_FLASH_MS 250

// The hold after a buzz: each LED drifts between dim and full brightness, and now and then
// one sparkles towards white. It has to be bold to show through the diffusing shell.
#define SHIMMER_RETARGET_PCT 6    // chance per frame that an LED picks a new level
#define SHIMMER_MIN 0.2f          // dimmest level an LED drifts to
#define SHIMMER_EASE 0.2f         // fraction of the way to its new level per frame
#define SPARKLE_PER_MILLE 10      // chance per LED per frame of a sparkle, in thousandths
#define SPARKLE_DECAY 0.88f       // per frame; about 150 ms to fade

static float shimmer[N], shimmer_target[N], sparkle[N];

static void draw_buzz(uint32_t now, RgbColor *before) {
	if((int32_t)(now - base_start) < 0) {
		// Not this tree's turn yet: keep showing what was there
		for(int i = 0; i < N; i++) frame[i] = before[i];
		return;
	}
	uint32_t t = now - base_start;
	if(t < BUZZ_SPIN_MS) {
		// Accelerating: position is the integral of a linearly increasing speed
		float s = (float)t / BUZZ_SPIN_MS;
		float head = fwrap(s * s * 3.0f) * N;
		for(int i = 0; i < N; i++) {
			float behind = fmodf(head - i + N, N);
			float b = powf(0.45f, behind);
			frame[i] = hsb(buzz_hue, behind < 0.6f ? 0.3f : 1.0f, b);
		}
	} else if(t < BUZZ_SPIN_MS + BUZZ_FLASH_MS) {
		float s = (float)(t - BUZZ_SPIN_MS) / BUZZ_FLASH_MS;
		for(int i = 0; i < N; i++) frame[i] = hsb(buzz_hue, s, 1);
	} else {
		for(int i = 0; i < N; i++) {
			if(random(0, 100) < SHIMMER_RETARGET_PCT)
				shimmer_target[i] = SHIMMER_MIN + (1.0f - SHIMMER_MIN) * frand();
			shimmer[i] += (shimmer_target[i] - shimmer[i]) * SHIMMER_EASE;
			if(random(0, 1000) < SPARKLE_PER_MILLE) sparkle[i] = 1.0f;
			else sparkle[i] *= SPARKLE_DECAY;
			frame[i] = hsb(buzz_hue, 1.0f - 0.8f * sparkle[i], fmaxf(shimmer[i], sparkle[i]));
		}
	}
}

//-------------------------------------------------------------------------------------------------
// Countdown: the ring empties from green to red; at zero it flashes red

static void draw_countdown(uint32_t now) {
	if(countdown <= 0) {
		bool on = ((now - base_start) / 250) % 2 == 0;
		for(int i = 0; i < N; i++) frame[i] = on ? hsb(0, 1, 1) : RgbColor(0);
		return;
	}
	float lit = countdown * N / 100.0f;
	float h = 0.33f * countdown / 100.0f;
	for(int i = 0; i < N; i++) frame[i] = hsb(h, 1, clamp01(lit - i));
}

//-------------------------------------------------------------------------------------------------
// Overlays: rise quickly, decay over overlay_decay, blended over the base

#define OVERLAY_RISE_MS 80

static void draw_overlay(uint32_t now) {
	if(overlay == O_NONE || (int32_t)(now - overlay_start) < 0) return;
	uint32_t t = now - overlay_start;
	float a;
	if(t < OVERLAY_RISE_MS) a = (float)t / OVERLAY_RISE_MS;
	else if(t < OVERLAY_RISE_MS + overlay_decay) a = 1.0f - (float)(t - OVERLAY_RISE_MS) / overlay_decay;
	else { overlay = O_NONE; return; }
	for(int i = 0; i < N; i++) frame[i] = RgbColor::LinearBlend(frame[i], overlay_col, a);
}

static void start_overlay(OverlayMode m, RgbColor c, uint32_t delay_ms, uint32_t decay_ms) {
	overlay = m;
	overlay_col = c;
	overlay_start = millis() + delay_ms;
	overlay_decay = decay_ms;
}

//-------------------------------------------------------------------------------------------------

void tree_init() {
	ring_begin(TREE_LED_PIN);
	for(int i = 0; i < N; i++) out[i] = RgbColor(0);
	ring_show(out, N);
	randomSeed(esp_random());
	for(int i = 0; i < N; i++) {
		twinkles[i].phase = frand();
		twinkles[i].speed = 0.0004f + frand() * 0.0008f;
		twinkles[i].col = random(0, PALETTE_LEN);
		candle_level[i] = candle_target[i] = 0.5f;
		shimmer[i] = shimmer_target[i] = 1.0f;
		sparkle[i] = 0;
	}
}

void tree_tick(uint32_t now) {
	static uint32_t last = now;
	uint32_t dt = now - last;
	last = now;

	static RgbColor shown[N];   // last frame sent, for a buzz waiting its turn

	switch(base_mode) {
		case B_AMBIENT:
			switch(ambient_id) {
				case 1: ambient_twinkle(dt); break;
				case 2: ambient_rainbow(now); break;
				case 3: ambient_candle(); break;
				case 4: ambient_roomwave(now); break;
				case 5: ambient_chase(now); break;
				case 6: ambient_megamas(now, dt); break;
				case 7: ambient_megatree(now, dt); break;
				default: for(int i = 0; i < N; i++) frame[i] = RgbColor(0); break;
			}
			break;
		case B_SOLID:
			for(int i = 0; i < N; i++) frame[i] = solid_col;
			break;
		case B_BUZZ:
			draw_buzz(now, shown);
			break;
		case B_COUNTDOWN:
			draw_countdown(now);
			break;
		case B_SINGLE:
			for(int i = 0; i < N; i++) frame[i] = RgbColor(i == single_led ? 255 : 0);
			break;
	}
	draw_overlay(now);

	for(int i = 0; i < N; i++) {
		shown[i] = frame[i];
		out[i] = gamma_table.Correct(frame[i]).Dim(brightness);
	}
	ring_show(out, N);
}

void tree_set_identity(int index, int count) {
	if(count < 1) count = 1;
	if(index < 0 || index >= count) index = 0;
	my_index = index;
	tree_count = count;
}

void tree_set_team_count(int n) {
	if(n > 0) team_hue_slices = n;
}

void tree_set_brightness(uint8_t b) {
	brightness = b;
}

void tree_ambient(int id) {
	if((id == 6 || id == 7) && !(base_mode == B_AMBIENT && ambient_id == id)) {
		// Start all red, as the string's Megamas does
		for(int i = 0; i < N; i++) mega_hue[i] = mega_target[i] = 0;
		mega_next = millis();
		mega_beat = -1;
	}
	base_mode = B_AMBIENT;
	ambient_id = id;
	base_start = millis();
}

void tree_solid(RgbColor c) {
	base_mode = B_SOLID;
	solid_col = c;
}

void tree_team_colour(int team) {
	tree_solid(hsb(team_hue(team), 1, 1));
}

void tree_buzz(int team) {
	base_mode = B_BUZZ;
	buzz_hue = team_hue(team);
	base_start = millis() + (uint32_t)my_index * TREE_STAGGER_MS;
	for(int i = 0; i < N; i++) {
		shimmer[i] = shimmer_target[i] = 1.0f;
		sparkle[i] = 0;
	}
}

void tree_countdown(int percent) {
	if(percent < 0) percent = 0;
	if(percent > 100) percent = 100;
	if(base_mode != B_COUNTDOWN || (percent == 0) != (countdown == 0)) base_start = millis();
	base_mode = B_COUNTDOWN;
	countdown = percent;
}

void tree_pulse_colour(int id) {
	RgbColor c = id == 1 ? RgbColor(255, 0, 0) : (id == 2 ? RgbColor(0, 255, 0) : RgbColor(255));
	start_overlay(O_PULSE, c, 0, 1200);
}

void tree_pulse_team(int param) {
	bool quick = param >= 50;
	int team = quick ? param - 50 : param;
	start_overlay(O_PULSE, hsb(team_hue(team), 1, 1), 0, quick ? 300 : 1200);
}

void tree_wave(int step_ms) {
	start_overlay(O_WAVE, RgbColor(255), (uint32_t)my_index * step_ms, 350);
}

void tree_show_progress(int done, int total) {
	float lit = total > 0 ? (float)done * N / total : 0;
	for(int i = 0; i < N; i++) {
		RgbColor c = hsb(0.62f, 0.8f, clamp01(lit - i));
		out[i] = gamma_table.Correct(c).Dim(brightness);
	}
	ring_show(out, N);
}

void tree_single(int led) {
	base_mode = B_SINGLE;
	single_led = led;
}
