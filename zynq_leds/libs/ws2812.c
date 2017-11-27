#include <inttypes.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <stdio.h>
#include "ws2812.h"
#include "fast_hsv2rgb.h"

int ws2812_leds_init(struct ws2812_leds_dev *leds, off_t base_address, int num_leds) {
	leds->base_address = base_address;
	leds->num_leds = num_leds;
	leds->memf = open("/dev/mem", O_RDWR | O_SYNC);
	if (leds->memf == -1) {
		perror("Can't open /dev/mem");
		ws2812_leds_destroy(leds);
		return 1;
	}
	leds->mem = mmap(NULL, REG_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, leds->memf, leds->base_address);
	if (leds->mem == MAP_FAILED) {
		perror("Can't map device memory");
		ws2812_leds_destroy(leds);
		return 1;
	}
	return 0;
}

void ws2812_leds_destroy(struct ws2812_leds_dev *leds) {
	if (leds->mem != 0 && leds->mem != MAP_FAILED) {
		munmap((uint32_t *)&leds->mem_nv, REG_SIZE);
	}
	if (leds->memf != -1) {
		close(leds->memf);
	}
}

void ws2812_leds_reset(struct ws2812_leds_dev *leds) {
	leds->mem[0] = 4;
	leds->mem[0] = 0;
	ws2812_leds_wait(leds);
}

void ws2812_leds_display(struct ws2812_leds_dev *leds) {
	leds->mem[0] = 2;
	leds->mem[0] = 0;
	ws2812_leds_wait(leds);
}

void ws2812_leds_clear(struct ws2812_leds_dev *leds) {
	ws2812_leds_reset(leds);
	ws2812_leds_display(leds);
}

uint32_t ws2812_leds_status(struct ws2812_leds_dev *leds) {
	return leds->mem[0];
}

void ws2812_leds_wait(struct ws2812_leds_dev *leds) {
	while (ws2812_leds_status(leds));
}

void ws2812_led_set_rgb(struct ws2812_leds_dev *leds, uint32_t address, uint8_t red,
                        uint8_t green, uint8_t blue) {
	leds->mem[0] = 0;
	leds->mem[1] = address;
	leds->mem[2] = red << 16 | green << 8 | blue;
	leds->mem[0] = 1;
	leds->mem[0] = 0;
}

void ws2812_led_set_hsv(struct ws2812_leds_dev *leds, uint32_t address, uint16_t h,
                        uint8_t s, uint8_t v) {
	uint8_t r, g, b;
	fast_hsv2rgb_32bit(h, s, v, &r, &g, &b);
	ws2812_led_set_rgb(leds, address, r, g, b);
}
