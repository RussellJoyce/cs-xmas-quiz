#include <inttypes.h>
#include <sys/types.h>
#include "fast_hsv2rgb.h"

#define REG_SIZE 12

struct ws2812_leds_dev {
        union {
		volatile uint32_t *mem;
		uint32_t *mem_nv;
        };
	int num_leds;
	off_t base_address;
	int memf;
};

int ws2812_leds_init(struct ws2812_leds_dev *leds, off_t base_address, int num_leds);
void ws2812_leds_destroy(struct ws2812_leds_dev *leds);
void ws2812_leds_reset(struct ws2812_leds_dev *leds);
void ws2812_leds_display(struct ws2812_leds_dev *leds);
void ws2812_leds_clear(struct ws2812_leds_dev *leds);
uint32_t ws2812_leds_status(struct ws2812_leds_dev *leds);
void ws2812_leds_wait(struct ws2812_leds_dev *leds);
void ws2812_led_set_rgb(struct ws2812_leds_dev *leds, uint32_t address, uint8_t red, uint8_t green, uint8_t blue);
void ws2812_led_set_hsv(struct ws2812_leds_dev *leds, uint32_t address, uint16_t h, uint8_t s, uint8_t v);
