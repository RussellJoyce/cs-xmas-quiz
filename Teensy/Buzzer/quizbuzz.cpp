#include "quizbuzz.h"

typedef struct {
	int st;
	int end;
} bounds_t;

bounds_t teams[NUM_TEAMS] = {
	{  0,  24}, //Team 1
	{ 25,  49}, //Team 2
	{ 50,  74}, //Team 3
	{ 75,  99}, //Team 4
	{100, 124}, //Team 5
	{125, 149}, //Team 6
	{150, 174}, //Team 7
	{175, 199}, //Team 8
};

// Team colours as 45 degrees apart on the hue spectrum
CRGB teamcol[NUM_TEAMS] = {
	CHSV(  0, 255, 255), //Team 1 (0)
	CHSV( 32, 255, 255), //Team 2 (45)
	CHSV( 64, 255, 255), //Team 3 (90)
	CHSV( 96, 255, 255), //Team 4 (135)
	CHSV(128, 255, 255), //Team 5 (180)
	CHSV(160, 255, 255), //Team 6 (225)
	CHSV(192, 255, 255), //Team 7 (270)
	CHSV(224, 255, 255), //Team 8 (315)
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

