#include "quizbuzz.h"

typedef struct {
	int st;
	int end;
} bounds_t;

bounds_t teams[NUM_TEAMS] = {
	{  0,  19}, // Team 1
	{ 20,  39}, // Team 2
	{ 40,  59}, // Team 3
	{ 60,  79}, // Team 4
	{ 80,  99}, // Team 5
	{100, 119}, // Team 6
	{120, 134}, // Team 7
	{140, 159}, // Team 8
	{160, 179}, // Team 9
	{180, 199}, // Team 10
};

// Team colours as 36 degrees apart on the hue spectrum
CRGB teamcol[NUM_TEAMS] = {
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

#define NUM_FRAMES 170
#define FRAME_DELAY 0
#define SWOOP_TEAM_COLS 1
#define SWOOP_FADE_SPEED 8
#define POST_SWOOP_FADE_SPEED 5

void play_buzz_anim(int team) {
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
	for(int i = teams[team].st; i <= teams[team].end; i++) {
		leds[i] = col;
	}
	FastLED.show();
}

void set_team_buzz_colour(int team) {
	if(team < 0 || team >= NUM_TEAMS) return;
	for(int i = 0; i < NUM_LEDS; i++) {
		leds[i] = (i < teams[team].st || i > teams[team].end) ? CRGB::Black : teamcol[team];
	}
	FastLED.show();
}

