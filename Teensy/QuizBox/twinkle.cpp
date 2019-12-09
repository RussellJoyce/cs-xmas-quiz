#include "twinkle.h"

Twinkle *twinkle = new Twinkle();

#define SPEED            4  // Every speed frames change a target colour
#define HUE             85  // The hue of the leds
#define SATURATION     100  // The saturation of the leds
#define TWINKLE_AMOUNT  60  // The amount to twiddle the value of the leds

#define FADEFRAMES 4

CHSV target[NUM_LEDS];
CHSV current[NUM_LEDS];

void Twinkle::start() {
	for(int i = 0; i < NUM_LEDS; i++) {
		leds[i] = CHSV(HUE, SATURATION, 60);
		target[i] = CHSV(HUE, SATURATION, 60);
		current[i] = CHSV(HUE, SATURATION, 60);
	}
	// FastLED.show();
}

void Twinkle::tick() {
	static int framenum;
	static int fadeframenum;

	framenum++;
	fadeframenum++;

	if(framenum > SPEED) {
		framenum = 0;
		int s = SATURATION + 20 - random(40);
		int v = random(TWINKLE_AMOUNT) + 25;
		if (random(15) == 0)
			v *= 3;
		target[random(NUM_LEDS)] = CHSV(HUE, s, v);
	}

	if(fadeframenum > FADEFRAMES) {
		fadeframenum = 0;
		for(int i = 0; i < NUM_LEDS; i++) {
			if(current[i].v < target[i].v) current[i].v++;
			if(current[i].v > target[i].v) current[i].v--;
			if(current[i].s < target[i].s) current[i].s++;
			if(current[i].s > target[i].s) current[i].s--;
			current[i].h = HUE;
			leds[i] = current[i];
		}
		FastLED.show();
	}
}
