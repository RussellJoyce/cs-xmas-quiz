#include "quizbuzz.h"

// Team colours as 36 degrees apart on the hue spectrum
CHSV teamcol[NUM_TEAMS] = {
	CHSV(  0, 255, 255), // Team 1  (  0)
	CHSV( 25, 255, 255), // Team 2  ( 36)
	CHSV( 51, 255, 255), // Team 3  ( 72)
	CHSV( 76, 255, 255), // Team 4  (108)
	CHSV(102, 255, 255), // Team 5  (144)
	CHSV(128, 255, 255), // Team 6  (180)
	CHSV(153, 255, 255), // Team 7  (216)
	CHSV(179, 255, 255), // Team 8  (252)
	CHSV(204, 255, 255), // Team 9  (288)
	CHSV(230, 255, 255), // Team 10 (324)
};


int ledstringpos(int x) {
	if(x % 2) {
		//odd
		return 200 - ((x+1)/2);
	} else {
		return x/2;
	}
}


void play_buzz_anim(int team) {
	int frame;
	if(team < 0 || team >= NUM_TEAMS) return;

	//Fade in
	#define MID (NUM_LEDS/2)
	for(frame = 0; frame < 170; frame++) {
		int brightness;
		for(int x = 0; x < NUM_LEDS; x++) {
			if(x < MID) brightness = (frame * 2) - x;
			else brightness = (frame * 2) - (NUM_LEDS - x);
			if(brightness > 255) brightness = 255;
			if(brightness < 0) brightness = 0;
			leds[ledstringpos(x)] = CRGB(brightness, brightness, brightness);
		}
		FastLED.show();
		delay(0);
	}

	//Fade to colour
	int fadespeed[NUM_LEDS];
	for(int x = 0; x < NUM_LEDS; x++) {
		fadespeed[x] = random(4) + 1;
	}

	for(frame = 0; frame < 255; frame++) {
		for(int x = 0; x < NUM_LEDS; x++) {
			int sat = frame * fadespeed[x];
			if(sat > 255) sat = 255;
			leds[ledstringpos(x)] = CHSV(teamcol[team].hue, sat, 255);
		}
		FastLED.show();
		delay(1);
	}
}

void play_pointless_wrong() {
	clearLEDs();

	// Fade in fast
	for (int frame = 0; frame < 10; frame++) {
		for (int led = 0; led < NUM_LEDS; led++) {
			leds[led] = CHSV(0, 255, frame * 25);
		}
		FastLED.show();
	}

	// Fade out slowly
	for (int frame = 255; frame >= 0; frame--) {
		for (int led = 0; led < NUM_LEDS; led++) {
			leds[led] = CHSV(0, 255, frame);
		}
		FastLED.show();
	}

	clearLEDs();
}

void play_pointless_correct() {
	clearLEDs();

	// Fade in fast
	for (int frame = 0; frame < 10; frame++) {
		for (int led = 0; led < NUM_LEDS; led++) {
			leds[led] = CHSV(0, 0, frame * 25);
		}
		FastLED.show();
	}

	// Fade out slowly
	for (int frame = 255; frame >= 0; frame--) {
		for (int led = 0; led < NUM_LEDS; led++) {
			leds[led] = CHSV(0, 0, frame);
		}
		FastLED.show();
	}

	clearLEDs();
}

void set_team_colour(int team, CRGB col) {
	if(team < 0 || team >= NUM_TEAMS) return;
	for(int i = 0; i < NUM_LEDS; i++) {
		leds[i] = teamcol[team];
	}
	FastLED.show();
}

void set_team_buzz_colour(int team) {
	if(team < 0 || team >= NUM_TEAMS) return;
	for(int i = 0; i < NUM_LEDS; i++) {
		leds[i] = teamcol[team];
	}
	FastLED.show();
}



/*void play_buzz_anim_old(int team) {
	if(team < 0 || team >= NUM_TEAMS) return;

	clearLEDs();

	int right_dist = (NUM_LEDS - teams[team].end) - 1;

	//'Swoop' part of the animation where leds stream from the left and right
	//to focus on the target range
	for(int frame = 0; frame < NUM_FRAMES; frame++) {

		float pos = (float) frame / (float) NUM_FRAMES;

		int leftpos = round((float) teams[team].st * pos);
		int rightpos = (NUM_LEDS - round((float) right_dist * pos)) - 1;

		if(SWOOP_TEAM_COLS) { //Use team colours for the swoop
			leds[leftpos] = teamcol[team];
			leds[rightpos] = teamcol[team];
		} else { //Use random colours
			leds[leftpos] = CHSV(random(255), 255, 255);
			leds[rightpos] = CHSV(random(255), 255, 255);
		}

		fadeAllLeds(SWOOP_FADE_SPEED);	

		FastLED.show();
		delay(FRAME_DELAY);
	}

	//Swoop complete, focus on the target range
	for(int i = teams[team].st; i <= teams[team].end; i++) {
		leds[i] = teamcol[team];
	}
	FastLED.show();

	while(1) {
		int rv1 = fadeLeds(2, 0, teams[team].st - 1);
		int rv2 = fadeLeds(2, teams[team].end + 1, NUM_LEDS - 1);
		if(rv1 == 0 && rv2 == 0) break;
		FastLED.show();
		delay(POST_SWOOP_FADE_SPEED);
	}
}*/






