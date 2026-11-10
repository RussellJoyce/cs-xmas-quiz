/*
The Arduino core functions quizleds uses: a clock, delay, random, and the two global
objects the firmware talks to. Serial's actual I/O lives in the front end (simmain.cpp)
because it is the thing that owns the terminal.
*/

#include <Arduino.h>
#include <WiFi.h>

#include <chrono>
#include <thread>

SerialClass Serial;
WiFiClass WiFi;

static const std::chrono::steady_clock::time_point boot = std::chrono::steady_clock::now();

unsigned long millis() {
	return (unsigned long) std::chrono::duration_cast<std::chrono::milliseconds>(
		std::chrono::steady_clock::now() - boot).count();
}

unsigned long micros() {
	return (unsigned long) std::chrono::duration_cast<std::chrono::microseconds>(
		std::chrono::steady_clock::now() - boot).count();
}

void delay(unsigned long ms) {
	std::this_thread::sleep_for(std::chrono::milliseconds(ms));
}

//Arduino's random(howbig) yields 0..howbig-1, and returns 0 for a non-positive range.
long random(long howbig) {
	if(howbig <= 0) return 0;
	return rand() % howbig;
}

long random(long howsmall, long howbig) {
	if(howsmall >= howbig) return howsmall;
	return howsmall + random(howbig - howsmall);
}

void randomSeed(unsigned long seed) {
	srand((unsigned int) seed);
}

//-------------------------------------------------------------------------------------------------
// esp_system.h. A locally administered MAC, so it cannot be mistaken for a real board's.

static uint8_t sim_mac[6] = {0x02, 0x00, 0x00, 0x51, 0x00, 0x01};
static uint32_t entropy = 0x9e3779b9u;

void sim_set_mac(const uint8_t mac[6]) { memcpy(sim_mac, mac, sizeof(sim_mac)); }

void sim_set_entropy(uint32_t seed) { entropy = seed ? seed : 0x9e3779b9u; }

int esp_read_mac(uint8_t* mac, esp_mac_type_t type) {
	(void) type;
	memcpy(mac, sim_mac, sizeof(sim_mac));
	return 0;
}

//xorshift32: the firmware only uses it to seed random(), so it need not be good
uint32_t esp_random() {
	entropy ^= entropy << 13;
	entropy ^= entropy >> 17;
	entropy ^= entropy << 5;
	return entropy;
}
