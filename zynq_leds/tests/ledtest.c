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

	printf("LEDs test\n");

	if (ws2812_leds_init(&leds, BASE_ADDR, NUM_LEDS))
		return 1;

	printf("Clearing LEDs...");
	ws2812_leds_clear(&leds);
	printf("done\n");

	sleep(1);

	printf("Setting first three LEDs to R G B...");
	ws2812_led_set_rgb(&leds, 0, 0xff, 0x00, 0x00);
	ws2812_led_set_rgb(&leds, 1, 0x00, 0xff, 0x00);
	ws2812_led_set_rgb(&leds, 2, 0x00, 0x00, 0xff);
	ws2812_leds_display(&leds);
	printf("done\n");

	sleep(1);

	printf("Clearing LEDs...");
	ws2812_leds_clear(&leds);
	printf("done\n");

	sleep(1);

	printf("Fading first three LEDs...");
	for (int j = 0; j < 3; j++) {
		for (int i = 0xff; i > 0; i--) {
			ws2812_led_set_rgb(&leds, 0, i, 0x00, 0x00);
			ws2812_led_set_rgb(&leds, 1, 0x00, i, 0x00);
			ws2812_led_set_rgb(&leds, 2, 0x00, 0x00, i);
			ws2812_leds_display(&leds);
			usleep(1000);
		}
		for (int i = 0; i < 0xff; i++) {
			ws2812_led_set_rgb(&leds, 0, i, 0x00, 0x00);
			ws2812_led_set_rgb(&leds, 1, 0x00, i, 0x00);
			ws2812_led_set_rgb(&leds, 2, 0x00, 0x00, i);
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
	uint8_t r = 0, g = 0, b = 0;
	for (int i = 0; i < NUM_LEDS/2; i++) {
		if (i % 10 == 0) {
			if (r == 0xff) {
				r = 0x00;
				g = 0xff;
				b = 0x00;
			}
			else if (g == 0xff) {
				r = 0x00;
				g = 0x00;
				b = 0xff;
			}
			else {
				r = 0xff;
				g = 0x00;
				b = 0x00;
			}
		}
		ws2812_led_set_rgb(&leds, i, r, g, b);
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
		ws2812_led_set_rgb(&leds, i % NUM_LEDS, 0xff, 0xff, 0xff);
		ws2812_led_set_rgb(&leds, (i - 1) % NUM_LEDS, 0x40, 0x40, 0x40);
		ws2812_led_set_rgb(&leds, (i - 2) % NUM_LEDS, 0x20, 0x20, 0x20);
		ws2812_led_set_rgb(&leds, (i - 3) % NUM_LEDS, 0x10, 0x10, 0x10);
		ws2812_led_set_rgb(&leds, (i - 4) % NUM_LEDS, 0x00, 0x00, 0x00);
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
