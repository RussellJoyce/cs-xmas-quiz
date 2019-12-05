#ifndef __megamas_h
#define __megamas_h

#include <FastLED.h>
#include "boardconfig.h"
#include "library.h"

class Megamas : public Animation {
public:
	void start();
	void tick();
};

extern Megamas *megamas;


#endif
