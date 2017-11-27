#include <stdio.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <inttypes.h>
#include <time.h>
#include <stdlib.h>
#include "ws2812.h"

#define BASE_ADDR 0x40000000
#define NUM_LEDS 200

int main(int argc __attribute__((unused)), char *argv[] __attribute__((unused))) {

	struct ws2812_leds_dev leds;

	setbuf(stdout, NULL);

	printf("Megamas test\n");

	if (ws2812_leds_init(&leds, BASE_ADDR, NUM_LEDS))
		return 1;

	printf("Clearing LEDs...");
	ws2812_leds_clear(&leds);
	printf("done\n");

	sleep(1);

	// Set all LEDs to a random hue
	uint16_t random;
	for (int i = 0; i < NUM_LEDS; i++) {
		random = rand() % HSV_HUE_MAX;
		ws2812_led_set_hsv(&leds, i, random, HSV_SAT_MAX, HSV_VAL_MAX/4);
	}
	ws2812_leds_display(&leds);

	// Pick an LED and set it to a random hue (a few thousand times)
	uint32_t led;
	for (int i = 0; i < 2000; i++) {
		random = rand() % HSV_HUE_MAX;
		led = rand() % NUM_LEDS;
		ws2812_led_set_hsv(&leds, led, random, HSV_SAT_MAX, HSV_VAL_MAX/4);
		ws2812_leds_display(&leds);
		usleep(10000);
	}

	sleep(1);

	printf("Clearing LEDs...");
	ws2812_leds_clear(&leds);
	printf("done\n");

	ws2812_leds_destroy(&leds);

	printf("Finished.\n");

	return 0;
}
