#include "quizbuzz.h"
#include "ledmapping.h"

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

//Animation prototypes
void sweeptocentre(int team);
void sparklesweepl(int team);
void sparklesweepr(int team);
void pulses(int team);
void build(int team);
void colourwipe1(int team);
void colourwipe2(int team);
void colourwipe3(int team);


//Animation typedefs
typedef void (*buzzanim_p)(int);
buzzanim_p anims[] = {sweeptocentre, sparklesweepl, sparklesweepr, pulses, build, colourwipe1, colourwipe2, colourwipe3};

//Play a random buzzer animation
bool randommode = true;
void play_buzz_anim(int team) {
	if(randommode) {
		anims[random(sizeof(anims) / sizeof(buzzanim_p))](team);
	} else {
		if(team >= 0 && team <= (int)(sizeof(anims) / sizeof(buzzanim_p))) {
			anims[team](team);
		} else {
			if(team == 9) randommode = true;
		}
	}
}


void colourwipe_base(int team, bool fromleft, bool usemappings) {
	clearLEDs();
	for(int x = 0; x < NUM_LEDS; x++) {
		int y = x;
		if(!fromleft) y = NUM_LEDS - y;
		if(usemappings) y = ledlookup[y];
		leds[y] = teamcol[team];
		FastLED.show();
	}
}

void colourwipe1(int team) {
	colourwipe_base(team, true, true);
}

void colourwipe2(int team) {
	colourwipe_base(team, false, true);	
}

void colourwipe3(int team) {
	colourwipe_base(team, true, false);	
}


void build(int team) {
	clearLEDs();
	int values[NUM_LEDS];
	for(int i = 0; i < NUM_LEDS; i++) values[i] = 0;

	for(int frame = 0; frame < 200; frame++) {
		for(int x = 0; x < 10; x++) {
			int led = random(NUM_LEDS);
			values[led] += 30;
			values[led] = constrain(values[led], 0, 255);
			leds[led] = CHSV(teamcol[team].hue, 255, values[led]); 
		}
		FastLED.show();
	}
}


void pulses(int team) {
	for(int pulse = 0; pulse < 5; pulse++) {
		int hue = random(255);
		for(int i = 0; i < NUM_LEDS; i++) leds[i] = CHSV(hue, 255, 255);
		FastLED.show();
		for(int fadeframes = 0; fadeframes < 20; fadeframes++) {
			fadeAllLeds(5);
			FastLED.show();
		}
	}
	for(int i = 0; i < NUM_LEDS; i++) leds[i] = teamcol[team];
	FastLED.show();
}


void fadeToHue(int hue, bool fromwhite) {
	int fadespeed[NUM_LEDS];
	for(int x = 0; x < NUM_LEDS; x++) {
		fadespeed[x] = random(4) + 1;
	}

	for(int frame = 0; frame < 127; frame++) {
		for(int x = 0; x < NUM_LEDS; x++) {
			int v = constrain(frame * fadespeed[x] * 2, 0, 255);
			if(fromwhite) 
				//Fade saturation (so from white to target colour)
				leds[ledlookup[x]] = CHSV(hue, v, 255);
			else
				//Fade Value (so from black to target colour)
				leds[ledlookup[x]] = CHSV(hue, 255, v);
		}
		FastLED.show();
		delay(1);
	}
}

void sparklesweep(int team, bool fromleft) {
	clearLEDs();
	for(int x = 0; x < NUM_LEDS; x += 2) {
		int y = constrain(x + ((int) random(20) - 10), 0, NUM_LEDS);
		int hue = (teamcol[team].hue + (random(64) - 32)) % 360;

		if(fromleft)
			leds[ledlookup[y]] = CHSV(hue, 255, 255);
		else
			leds[ledlookup[NUM_LEDS-y]] = CHSV(hue, 255, 255);

		fadeAllLeds(4);
		FastLED.show();
	}
 	fadeLEDsOut(4);

 	fadeToHue(teamcol[team].hue, false);
}

void sparklesweepl(int team) {
	sparklesweep(team, true);
}

void sparklesweepr(int team) {
	sparklesweep(team, false);
}

void sweeptocentre(int team) {
	if(team < 0 || team >= NUM_TEAMS) return;

	//Fade in
	for(int frame = 0; frame < 170; frame++) {
		int brightness;
		for(int x = 0; x < NUM_LEDS; x++) {
			if(x < NUM_LEDS/2) 
				brightness = (frame * 2) - x;
			else 
				brightness = (frame * 2) - (NUM_LEDS - x);
			brightness = constrain(brightness, 0, 255);
			leds[ledlookup[x]] = CRGB(brightness, brightness, brightness);
		}
		FastLED.show();
		delay(0);
	}
	fadeToHue(teamcol[team].hue, true);
}


void pointlessfade(bool white) {
	clearLEDs();
	int saturation = white ? 0 : 255;

	// Fade in fast
	for (int frame = 0; frame < 10; frame++) {
		for (int led = 0; led < NUM_LEDS; led++) {
			leds[led] = CHSV(0, saturation, frame * 25);
		}
		FastLED.show();
	}

	// Fade out slowly
	for (int frame = 255; frame >= 0; frame--) {
		for (int led = 0; led < NUM_LEDS; led++) {
			leds[led] = CHSV(0, saturation, frame);
		}
		FastLED.show();
	}

	clearLEDs();
}

void play_pointless_wrong() {
	pointlessfade(false);
}

void play_pointless_correct() {
	pointlessfade(true);
}

void pointless_state(int state) {
	state = constrain(state, 0, 100);
	clearLEDs();
	for(int x = 0; x < round((float) state / 100.0f * (float) NUM_LEDS); x++) {
		leds[ledlookup[x]] = CRGB(255, 255, 0);
	}
	FastLED.show();
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






