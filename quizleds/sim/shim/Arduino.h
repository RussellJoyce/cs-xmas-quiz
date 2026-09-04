#ifndef SIM_ARDUINO_H
#define SIM_ARDUINO_H

/*
Host stand-in for the Arduino core.

Only the handful of things quizleds actually touches: a millisecond clock, delay,
random, the PROGMEM no-ops that NeoPixelBus' HtmlColor header wants, a String just
rich enough for web.cpp, and a Serial that talks to the simulator's console rather
than a UART.
*/

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>
#include <string>
#include <utility>

//-------------------------------------------------------------------------------------------------
// Flash-string access. The host has one flat address space, so all of this is a plain read.

#define PROGMEM
#define PGM_P const char*
#define pgm_read_byte(addr)  (*reinterpret_cast<const uint8_t*>(addr))
#define pgm_read_word(addr)  (*reinterpret_cast<const uint16_t*>(addr))
#define pgm_read_dword(addr) (*reinterpret_cast<const uint32_t*>(addr))
#define pgm_read_ptr(addr)   (*reinterpret_cast<const void* const*>(addr))
#define F(str) (str)

#define strlen_P(s)            strlen(s)
#define strncpy_P(d, s, n)     strncpy(d, s, n)
#define strcpy_P(d, s)         strcpy(d, s)
#define strcmp_P(a, b)         strcmp(a, b)
#define memcpy_P(d, s, n)      memcpy(d, s, n)

//-------------------------------------------------------------------------------------------------
// Time and randomness

unsigned long millis();
unsigned long micros();
void delay(unsigned long ms);

long random(long howbig);
long random(long howsmall, long howbig);
void randomSeed(unsigned long seed);

//-------------------------------------------------------------------------------------------------
// String. web.cpp uses it to hold credentials and hand them to WiFi.begin.

class String {
public:
	String() {}
	String(const char* s) : s(s ? s : "") {}
	String(const std::string& s) : s(s) {}
	const char* c_str() const { return s.c_str(); }
	size_t length() const { return s.length(); }
private:
	std::string s;
};

//-------------------------------------------------------------------------------------------------
// Serial. Output goes to the simulator console, input comes from the terminal, so the
// debug key interface in main.cpp's loop() works exactly as it does over a real UART.

//Implemented by the simulator front end (simconsole.cpp).
void sim_serial_out(const char* text, size_t len);
int sim_serial_available();
int sim_serial_read();

class SerialClass {
public:
	void begin(unsigned long) {}
	operator bool() const { return true; }

	int available() { return sim_serial_available(); }
	int read() { return sim_serial_read(); }

	void print(const char* s) { sim_serial_out(s, strlen(s)); }
	void print(char c) { sim_serial_out(&c, 1); }
	void print(const String& s) { sim_serial_out(s.c_str(), s.length()); }
	void print(int v) { printf("%d", v); }
	void print(unsigned long v) { printf("%lu", v); }

	void println() { sim_serial_out("\n", 1); }
	void println(const char* s) { print(s); println(); }
	void println(char c) { print(c); println(); }
	void println(const String& s) { print(s); println(); }
	void println(int v) { print(v); println(); }
	void println(unsigned long v) { print(v); println(); }

	//A variadic template rather than a plain varargs printf so that a String argument is
	//converted to a C string on the way through. web.cpp passes one (see README).
	template<typename... Args>
	void printf(const char* fmt, Args&&... args) {
		char buf[512];
		int n = snprintf(buf, sizeof(buf), fmt, arg(std::forward<Args>(args))...);
		if(n > 0) sim_serial_out(buf, (size_t) (n < (int) sizeof(buf) ? n : sizeof(buf) - 1));
	}

private:
	template<typename T> static T arg(T v) { return v; }
	static const char* arg(const String& s) { return s.c_str(); }
};

extern SerialClass Serial;

#endif
