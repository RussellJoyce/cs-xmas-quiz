#include "tree_ring.h"
#include "tree_settings.h"

// 10 MHz RMT clock, so durations are in 0.1 us. WS2812B: a 1 is 0.8 us high then 0.4 us low,
// a 0 is 0.4 us high then 0.8 us low (the same timings as the core's rgbLedWrite). The line
// rests low after each frame, and frames are far more than the 50 us reset time apart.
#define RMT_HZ 10000000
#define BITS_PER_LED 24

static int ring_pin = -1;
static rmt_data_t symbols[TREE_NUM_LEDS * BITS_PER_LED];

bool ring_begin(int pin) {
	// Two memory blocks (96 symbols) halves the refills needed for the 192 symbols of a frame.
	// Both the C3 and the C6 have two TX channels, so this takes all of the RMT TX memory.
	if(!rmtInit(pin, RMT_TX_MODE, RMT_MEM_NUM_BLOCKS_2, RMT_HZ)) {
		Serial.printf("RMT init failed on GPIO%d\n", pin);
		return false;
	}
	ring_pin = pin;
	return true;
}

void ring_show(const RgbColor *pixels, int count) {
	if(ring_pin < 0) return;
	if(count > TREE_NUM_LEDS) count = TREE_NUM_LEDS;
	int s = 0;
	for(int i = 0; i < count; i++) {
		uint8_t grb[3] = { pixels[i].G, pixels[i].R, pixels[i].B };
		for(int c = 0; c < 3; c++) {
			for(int bit = 7; bit >= 0; bit--) {
				bool one = grb[c] & (1 << bit);
				symbols[s].level0 = 1;
				symbols[s].duration0 = one ? 8 : 4;
				symbols[s].level1 = 0;
				symbols[s].duration1 = one ? 4 : 8;
				s++;
			}
		}
	}
	// A frame takes about 240 us; the timeout only guards against a stuck channel
	rmtWrite(ring_pin, symbols, s, 10);
}
