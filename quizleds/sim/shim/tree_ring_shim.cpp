/*
Host stand-in for the trees' ring driver (src/tree/tree_ring.cpp), which sends frames out
over the RMT peripheral. Here ring_show() hands them to the simulator front end instead, as
NeoPixelBus::Show() does for the string.
*/

#include <tree_ring.h>

bool ring_begin(int pin) {
	(void) pin;
	return true;
}

void ring_show(const RgbColor *pixels, int count) {
	sim_leds_show(pixels, (uint16_t) count);
}
