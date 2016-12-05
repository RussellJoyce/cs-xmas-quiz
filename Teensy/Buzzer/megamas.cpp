#include "megamas.h"

Megamas *megamas = new Megamas();

#define SPEED         4  // Speed of change
#define NUMBER       20  // Number of LEDs to change
#define TRANS_SPEED   3  // Transition speed


static CHSV target[NUM_LEDS];
static CHSV current[NUM_LEDS];


void Megamas::start() {
	for(int i = 0; i < NUM_LEDS; i++) {
		leds[i] = CHSV(0, 255, 255);
		target[i] = CHSV(0, 255, 255);
		current[i] = CHSV(0, 255, 255);
	}
	//FastLED.show();
}

void Megamas::tick() {
	static int framenum;

	framenum++;

	if(framenum > SPEED) {
		framenum = 0;
		for(int i = 0; i < NUMBER; i++) {
			switch(random(3)) {
				case 0:
					target[random(NUM_LEDS)] = CHSV(0, 255, 255);
					break;
				case 1:
					target[random(NUM_LEDS)] = CHSV(85, 255, 255);
					break;
				case 2:
					target[random(NUM_LEDS)] = CHSV(170, 255, 255);
					break;
			}
		}
	}

	for(int i = 0; i < NUM_LEDS; i++) {
		if(current[i].h < target[i].h) {
			if(target[i].h - current[i].h < TRANS_SPEED) {
				current[i].h = target[i].h;
			} else if(current[i].h < (255-TRANS_SPEED)) {
				current[i].h += TRANS_SPEED;
			} else {
				current[i].h = 255;
			}
		}

		if(current[i].h > target[i].h) {
			if(current[i].h - target[i].h < TRANS_SPEED) {
				current[i].h = target[i].h;
			} else if(current[i].h > TRANS_SPEED) {
				current[i].h -= TRANS_SPEED;
			} else {
				current[i].h = 0;
			}
		}

		leds[i] = current[i];
	}
	FastLED.show();
}
