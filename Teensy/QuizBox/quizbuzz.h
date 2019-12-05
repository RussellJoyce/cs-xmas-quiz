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

#define NUM_TEAMS 10

/*
Play the "swoosh" animation when a given team buzzes in. Clears all LEDs first,
and returns with only the LEDs of the buzzed team lit (in their colours)
*/
void play_buzz_anim(int team);

/*
Set the string to the given team colour
*/
void set_string_team_colour(int team);

/* 
Set the string to a given fixed colour
*/
void set_string_colour(int col);

/*
Pulse the LEDs in a team's colour
*/
void pulse_team_colour(int team);

/*
Play Pointless wrong animation
*/
void play_pointless_wrong();

/*
Play Pointless correct animation
*/
void play_pointless_correct();

/*
Set the pointless display to the given state (0-100)
*/
void pointless_state(int state);

/*
The colours assigned to each team.
*/
extern CHSV teamcol[NUM_TEAMS];

#endif
