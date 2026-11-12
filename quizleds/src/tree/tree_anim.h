#ifndef TREE_ANIM_H_
#define TREE_ANIM_H_

#include <Arduino.h>
#include <NeoPixelBus.h>

// What the tree shows is a base layer (an ambient animation, a solid colour, a buzz or a
// countdown) with an optional overlay on top (a pulse or a wave flash). Overlays fade out
// and leave the base showing again. Everything is timed from millis().

void tree_init();
void tree_tick(uint32_t now);

// This tree's place among those connected, from the server. Used to stagger effects and to
// put ambient animations out of phase so that they travel across the room.
void tree_set_identity(int index, int count);
void tree_set_team_count(int n);
void tree_set_brightness(uint8_t b);

// Base layer
void tree_ambient(int id);
void tree_solid(RgbColor c);
void tree_team_colour(int team);
void tree_buzz(int team);          // staggered by index
void tree_countdown(int percent);  // 0-100

// Overlays
void tree_pulse_colour(int id);    // 0 white, 1 red, 2 green
void tree_pulse_team(int param);   // team, or team + 50 for a quick pulse
void tree_wave(int step_ms);       // white flash, tree i fires at i * step_ms

// Firmware update: fills the ring in blue as the download goes. Draws and shows at once,
// because loop() is blocked for the whole download and tree_tick() is not running.
void tree_show_progress(int done, int total);

// Debugging
void tree_single(int led);

#endif
