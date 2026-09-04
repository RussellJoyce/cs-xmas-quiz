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
