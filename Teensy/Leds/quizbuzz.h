#ifndef __quizbuzz_h
#define __quizbuzz_h

#include <FastLED.h>
#include "boardconfig.h"
#include "library.h"

/*
The Quiz Buzzer code. This is independent of the rest of the system apart from:
	The NUM_LEDS macro from boardconfig
	Some simple led handling routines in library.cpp
*/

#define NUM_TEAMS 8

/*
Play the "swoosh" animation when a given team buzzes in. Clears all LEDs first,
and returns with only the LEDs of the buzzed team lit (in their colours)
*/
void play_buzz_anim(int team);

/*
Illuminate the LEDs of a given team in a given colour. Used by the True/False
round to indicate which teams are still in (green) and out (red).
*/
void set_team_colour(int team, CRGB col);

/*
The colours assigned to each team.
*/
extern CRGB teamcol[NUM_TEAMS];

#endif
