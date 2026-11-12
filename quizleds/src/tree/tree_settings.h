#ifndef TREE_SETTINGS_H_
#define TREE_SETTINGS_H_

// Desk tree: an ESP32-C3 SuperMini or ESP32-C6-Zero driving an 8 x WS2812B ring. See treelight/
// for the enclosure.

#define TREE_NUM_LEDS 8

// Set per board in tree/platformio.ini
#ifndef TREE_LED_PIN
#define TREE_LED_PIN 10
#endif

// ~60 FPS. Plenty for 8 LEDs; animations are timed in milliseconds, not frames.
#define TREE_MILLIS_PER_FRAME 16

// Global brightness 0-255 until the server sends a g command. Full white on all eight LEDs
// is ~480 mA, which with WiFi is more than a USB port promises, so stay well under.
#define TREE_DEFAULT_BRIGHTNESS 128

// Team colours are this many equal slices of the hue wheel until the server sends n, as on
// the string
#define TREE_DEFAULT_TEAM_HUE_SLICES 14

// How far apart neighbouring trees start a staggered effect such as a buzz
#define TREE_STAGGER_MS 90

// If true, do not connect to wifi; start on the twinkle so the LEDs can be checked
#define TREE_OFFLINE_MODE 0

#endif
