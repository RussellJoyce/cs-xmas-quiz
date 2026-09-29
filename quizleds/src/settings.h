#ifndef SRC_SETTINGS_H_
#define SRC_SETTINGS_H_

#define NUM_LEDS 200
#define HOSTNAME "quizleds"
#define LED_PIN 13

// Team colours are this many equal slices of the hue wheel until the server sends an n command
#define DEFAULT_TEAM_HUE_SLICES 14

//~77 FPS
#define MILLIS_PER_FRAME 13

// If true, take a few seconds on bootup in order to give time to view all boot messages
#define SLOW_BOOT 0

// If true, do not connect to wifi
#define OFFLINE_MODE 1

#endif /* SRC_SETTINGS_H_ */
