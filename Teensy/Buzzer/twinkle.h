#ifndef __twinkle_h
#define __twinkle_h

#include <FastLED.h>
#include "boardconfig.h"
#include "library.h"

class Twinkle : public Animation {
public:
	void start();
	void tick();
};

extern Twinkle *twinkle;


#endif
