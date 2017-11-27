#include <stdio.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <inttypes.h>
#include <time.h>
#include "ws2812.h"

#define BASE_ADDR 0x40000000
#define NUM_LEDS 200

int main(int argc __attribute__((unused)), char *argv[] __attribute__((unused))) {

	struct ws2812_leds_dev leds;

	setbuf(stdout, NULL);

	printf("HSV LEDs test\n");

	if (ws2812_leds_init(&leds, BASE_ADDR, NUM_LEDS))
		return 1;

	printf("Clearing LEDs...");
	ws2812_leds_clear(&leds);
	printf("done\n");

	sleep(1);

	printf("Setting first three LEDs to R G B...");
	ws2812_led_set_hsv(&leds, 0, 0, HSV_SAT_MAX, HSV_VAL_MAX);
	ws2812_led_set_hsv(&leds, 1, HSV_HUE_MAX / 3, HSV_SAT_MAX, HSV_VAL_MAX);
	ws2812_led_set_hsv(&leds, 2, HSV_HUE_MAX / 3 * 2, HSV_SAT_MAX,
	                   HSV_VAL_MAX);
	ws2812_leds_display(&leds);
	printf("done\n");

	sleep(1);

	printf("Clearing LEDs...");
	ws2812_leds_clear(&leds);
	printf("done\n");

	sleep(1);

	printf("Fading first three LEDs...");
	for (int j = 0; j < 3; j++) {
		for (int i = HSV_VAL_MAX; i > 0; i--) {
			ws2812_led_set_hsv(&leds, 0, 0, HSV_SAT_MAX, i);
			ws2812_led_set_hsv(&leds, 1, HSV_HUE_MAX / 3,
			                   HSV_SAT_MAX, i);
			ws2812_led_set_hsv(&leds, 2, HSV_HUE_MAX / 3 * 2,
			                   HSV_SAT_MAX, i);
			ws2812_leds_display(&leds);
			usleep(1000);
		}
		for (int i = 0; i < HSV_VAL_MAX; i++) {
			ws2812_led_set_hsv(&leds, 0, HSV_HUE_MIN, HSV_SAT_MAX, i);
			ws2812_led_set_hsv(&leds, 1, HSV_HUE_MAX / 3,
			                   HSV_SAT_MAX, i);
			ws2812_led_set_hsv(&leds, 2, HSV_HUE_MAX / 3 * 2,
			                   HSV_SAT_MAX, i);
			ws2812_leds_display(&leds);
			usleep(1000);
		}
	}
	printf("done\n");

	sleep(1);

	printf("Clearing LEDs...");
	ws2812_leds_clear(&leds);
	printf("done\n");

	sleep(1);

	printf("Setting half of LEDs to colours...");
	uint16_t hue = HSV_HUE_MAX/3*2;
	for (int i = 0; i < NUM_LEDS/2; i++) {
		if (i % 10 == 0) {
			if (hue == 0) {
				hue = HSV_HUE_MAX/3;
			}
			else if (hue == HSV_HUE_MAX/3) {
				hue = HSV_HUE_MAX/3*2;
			}
			else {
				hue = 0;
			}
		}
		ws2812_led_set_hsv(&leds, i, hue, HSV_SAT_MAX, HSV_VAL_MAX);
		ws2812_leds_display(&leds);

		usleep(50000);
	}
	printf("done\n");

	sleep(1);

	printf("Clearing LEDs...");
	ws2812_leds_clear(&leds);
	printf("done\n");

	sleep(1);

	printf("Setting single moving LED to white...");
	for (int i = 4; i < NUM_LEDS*5; i++) {
		ws2812_led_set_hsv(&leds, i % NUM_LEDS, 0, 0, 0xff);
		ws2812_led_set_hsv(&leds, (i - 1) % NUM_LEDS, 0, 0, 0x40);
		ws2812_led_set_hsv(&leds, (i - 2) % NUM_LEDS, 0, 0, 0x20);
		ws2812_led_set_hsv(&leds, (i - 3) % NUM_LEDS, 0, 0, 0x10);
		ws2812_led_set_hsv(&leds, (i - 4) % NUM_LEDS, 0, 0, 0x00);
		ws2812_leds_display(&leds);

		usleep(10000);
	}
	printf("done\n");

	sleep(1);

	printf("Clearing LEDs...");
	ws2812_leds_clear(&leds);
	printf("done\n");

	ws2812_leds_destroy(&leds);

	printf("Finished.\n");

	return 0;
}
