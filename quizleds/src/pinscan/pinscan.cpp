// Pin scanner for the LED string's board (classic ESP32), for finding which GPIO the strip's
// data line is on when the board cannot be seen. Build and flash from quizleds/:
//   pio run -e pinscan -t upload && pio device monitor -e pinscan
//
// It drives one candidate GPIO at a time with the string's LED timing and leaves every other
// candidate as an input. On the GPIO that is wired to the strip, the first N LEDs light up,
// where N is the GPIO number, in blocks of five alternating red and green, so GPIO 27 shows
// five blocks and two more: red green red green red, then two green. The strip is blanked before
// moving to the next pin, so it is only lit while the right one is being driven.
//
// Serial keys:
//   space   pause or resume the automatic scan (3 s per pin)
//   n / p   next / previous pin (and pause)
//   digits then Enter   go straight to that GPIO (and pause), e.g. "27" Enter
//   l       list the candidate pins
//
// Left out: 1 and 3 (UART0, the serial console), 6-11 (the flash) and 34-39 (inputs only).
// The strapping pins 0, 2, 5, 12 and 15 are included: only their level at reset matters.

#include <Arduino.h>
#include <NeoPixelBus.h>
#include "settings.h"   // the string's NUM_LEDS

// The string uses NeoWs2811Method, which on the ESP32 is the I2S method with WS2812x timing.
// RMT with the same timing is used here because its destructor hands the pin back as an
// input, so a pin can be driven and released in turn.
typedef NeoPixelBus<NeoRgbFeature, NeoEsp32Rmt0Ws2812xMethod> Bus;

static const int pins[] = { 0, 2, 4, 5, 12, 13, 14, 15, 16, 17, 18, 19, 21, 22, 23, 25, 26, 27,
                            32, 33 };
static const int NUM_PINS = sizeof(pins) / sizeof(pins[0]);
static const uint32_t STEP_MS = 3000;
static const uint8_t LEVEL = 60;   // dim, to keep the current down

static Bus *bus = NULL;
static int current = -1;           // index into pins
static bool paused = false;
static uint32_t last_step = 0;

static void release() {
	if(bus == NULL) return;
	bus->ClearTo(RgbColor(0));
	bus->Show();
	delete bus;   // waits for the blanking frame to finish, then makes the pin an input
	bus = NULL;
}

static void drive(int index) {
	release();
	current = (index + NUM_PINS) % NUM_PINS;
	int pin = pins[current];
	bus = new Bus(NUM_LEDS, pin);
	bus->Begin();
	bus->ClearTo(RgbColor(0));
	int lit = pin == 0 ? 1 : pin;   // GPIO 0 lights one white LED
	for(int i = 0; i < lit && i < NUM_LEDS; i++) {
		if(pin == 0) bus->SetPixelColor(i, RgbColor(LEVEL, LEVEL, LEVEL));
		else bus->SetPixelColor(i, (i / 5) % 2 == 0 ? RgbColor(LEVEL, 0, 0) : RgbColor(0, LEVEL, 0));
	}
	bus->Show();
	Serial.printf("GPIO %2d  (%d LEDs lit)%s\n", pin, pin == 0 ? 1 : pin, paused ? "  [paused]" : "");
	last_step = millis();
}

static void list_pins() {
	Serial.print("Candidates:");
	for(int i = 0; i < NUM_PINS; i++) Serial.printf(" %d", pins[i]);
	Serial.println();
}

void setup() {
	Serial.begin(115200);
	delay(500);
	// Every candidate an input to start with, so only the one being scanned drives anything
	for(int i = 0; i < NUM_PINS; i++) pinMode(pins[i], INPUT);
	Serial.println("\nLED string pin scanner. space pause, n/p step, digits+Enter jump, l list");
	list_pins();
	drive(0);
}

void loop() {
	static int typed = -1;   // a GPIO number being typed, or -1
	while(Serial.available()) {
		int c = Serial.read();
		if(c >= '0' && c <= '9') {
			typed = (typed < 0 ? 0 : typed * 10) + (c - '0');
			if(typed > 99) typed = 99;
		} else if(c == '\r' || c == '\n') {
			if(typed >= 0) {
				int found = -1;
				for(int i = 0; i < NUM_PINS; i++) if(pins[i] == typed) found = i;
				if(found < 0) {
					Serial.printf("GPIO %d is not a candidate\n", typed);
				} else {
					paused = true;
					drive(found);
				}
			}
			typed = -1;
		} else if(c == ' ') {
			paused = !paused;
			Serial.println(paused ? "Paused" : "Scanning");
			last_step = millis();
		} else if(c == 'n') {
			paused = true;
			drive(current + 1);
		} else if(c == 'p') {
			paused = true;
			drive(current - 1);
		} else if(c == 'l') {
			list_pins();
		}
	}
	if(!paused && millis() - last_step >= STEP_MS) drive(current + 1);
}
