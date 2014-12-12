#include "twinkle.h"

Twinkle *twinkle = new Twinkle();

#define SPEED            2  // Every speed frames change a target colour
#define HUE             60  // The hue of the leds
#define SATURATION     200  // The saturation of the leds
#define TWINKLE_AMOUNT 255  // The amount to twiddle the value of the leds

#define FADEFRAMES 4

CHSV target[NUM_LEDS];
CHSV current[NUM_LEDS];

void Twinkle::start() {
	for(int i = 0; i < NUM_LEDS; i++) {
		leds[i] = CHSV(HUE, SATURATION, 255);
		target[i] = CHSV(HUE, SATURATION, 255);
		current[i] = CHSV(HUE, SATURATION, 255);
	}
	//FastLED.show();
}

void Twinkle::tick() {
	static int framenum;
	static int fadeframenum;

	framenum++;
	fadeframenum++;

	if(framenum > SPEED) {
		framenum = 0;
		target[random(NUM_LEDS)] = CHSV(HUE, SATURATION, 255 - random(TWINKLE_AMOUNT));
	}

	if(fadeframenum > FADEFRAMES) {
		fadeframenum = 0;
		for(int i = 0; i < NUM_LEDS; i++) {
			if(current[i].v < target[i].v) current[i].v++;
			if(current[i].v > target[i].v) current[i].v--;
			current[i].s = SATURATION;
			current[i].h = HUE;
			leds[i] = current[i];
		}
		FastLED.show();
	}
}
