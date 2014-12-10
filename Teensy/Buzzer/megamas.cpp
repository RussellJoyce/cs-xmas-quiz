#include "megamas.h"

Megamas *megamas = new Megamas();

//							Min 	Max		Step	Start
static Parameter mmasspeed(	0, 		100, 	10, 	0);
static Parameter mmasnum(	5, 		50, 	5, 		10);
static Parameter transpeed(	1, 		10, 	1, 		4);

static void reset(void *arg) {
	mmasspeed.reset();
	mmasnum.reset();
	transpeed.reset();
}


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

	if(framenum > mmasspeed.get()) {
		framenum = 0;
		for(int i = 0; i < mmasnum.get(); i++) {
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
			if(target[i].h - current[i].h < transpeed.get()) {
				current[i].h = target[i].h;
			} else if(current[i].h < (255-transpeed.get())) {
				current[i].h += transpeed.get();
			} else {
				current[i].h = 255;
			}
		}

		if(current[i].h > target[i].h) {
			if(current[i].h - target[i].h < transpeed.get()) {
				current[i].h = target[i].h;
			} else if(current[i].h > transpeed.get()) {
				current[i].h -= transpeed.get();
			} else {
				current[i].h = 0;
			}
		}

		leds[i] = current[i];
	}
	FastLED.show();
}
