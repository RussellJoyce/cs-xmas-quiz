#ifndef TREE_RING_H_
#define TREE_RING_H_

#include <NeoPixelBus.h>

// Output to the WS2812B ring through Arduino core 3's RMT API, which supports both the C3 and
// the C6. NeoPixelBus is still used for its colour classes, but not for output: it has no RMT
// method for the C6, only bit-banging, which turns interrupts off for every frame.

bool ring_begin(int pin);
void ring_show(const RgbColor *pixels, int count);   // count <= TREE_NUM_LEDS

#endif
