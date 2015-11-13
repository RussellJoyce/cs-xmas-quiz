#ifndef __LIBRARY_H
#define __LIBRARY_H

#include <FastLED.h>
#include "boardconfig.h"

/*
Base animation class.
*/
class Animation {
public:
	Animation();
	virtual void tick() = 0;
	virtual void start() = 0;
	virtual ~Animation();
};

/*
Simple utility class for storing a parameter that can be incremented and 
decremented easily.
*/
class Parameter {
public:
	Parameter(int minval, int maxval, int step, int start_val);
	void inc();
	void dec();
	int get();
	void set(int v);
	void reset();
private:
	int val;
	int step;
	int minval;
	int maxval;
	int start_val;
};

//LED utility functions
void clearLEDs();
int fadeAllLeds(int speed);
int fadeLeds(int speed, int start, int end);
void setLed(uint8_t led, uint8_t colour);

//Menu utility functions
void param_inc(void *dir);
void param_dec(void *dir);

#endif
