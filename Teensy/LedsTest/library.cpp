#include "library.h"

void setLEDs(CRGB col) {
	for(int i = 0; i < NUM_LEDS; i++) {
		leds[i] = col;
	}
	FastLED.show();
}

void setLed(uint8_t led, uint8_t colour) {
	leds[led] = CRGB(colour, colour, colour);
	FastLED.show();
}

void clearLEDs() {
	setLEDs(CRGB(0, 0, 0));
}


int fadeLeds(int speed, int start, int end) {
	int still_on = 0;
	for(int led = start; led <= end; led++) {
		for(int i = 0; i < 3; i++) {
			if(leds[led].raw[i] > speed) {
				leds[led].raw[i] = leds[led].raw[i] - speed;
				still_on = 1;
			} else if(leds[led].raw[i] > 0) { //&& <= speed
				leds[led].raw[i] = 0;
				still_on = 1;
			}
		}
	}
	return still_on;
}

int fadeAllLeds(int speed) {
	return fadeLeds(speed, 0, NUM_LEDS - 1);
}


Animation::Animation() {}
Animation::~Animation() {}


Parameter::Parameter(int minval, int maxval, int step, int start_val) : 
		step(step), minval(minval), maxval(maxval), val(start_val), start_val(start_val) {}

void Parameter::inc() {
	val += step;
	if(val > maxval) val = maxval;
}

void Parameter::dec() {
	val -= step;
	if(val < minval) val = minval;
}

int Parameter::get() {
	return val;
}

void Parameter::set(int v) {
	val = v;
}

void Parameter::reset() {
	val = start_val;
}


void param_inc(void *dir) { ((Parameter*)dir)->inc();}
void param_dec(void *dir) { ((Parameter*)dir)->dec();}
