#ifndef SRC_ANIMATION_H_
#define SRC_ANIMATION_H_

#include <NeoPixelBus.h>
#include "settings.h"

/*
Base animation class.
*/
class Animation {
public:
	Animation();
	virtual void tick() = 0;
	virtual void start(int param) = 0;
	//True once a buzz animation has finished and is showing solid team colour, at which point
	//anim_tick() hands over to TeamHold. Other animations never settle.
	virtual bool settled() { return false; }
	virtual ~Animation();
};

typedef enum {
    NONE, MEGAMAS, TIMERTWINKLE, COLOURPULSE, TEAMPULSE, COUNTER, BUZZSWEEP1, BUZZSWEEP2, BUZZSWEEP3, BUZZSWEEP4, BUZZFLASH, BUZZCENTRE, BUZZRAINBOW, SWELL, EMBERS, BUZZCOMET, OLDLIGHTS, TEAMHOLD, BUZZSPLAT
} AnimID;

void anim_init();
void anim_tick();
void anim_set_anim(AnimID id, int param);
void clearLEDs();
void setLEDs(RgbColor col);
void setLEDsNoAnim(RgbColor col);
void anim_buzz_team(int teamid, int animtoplay = -1);
void anim_set_ambient(unsigned int id);
void set_music_levels(uint8_t leftAvg, uint8_t leftPeak, uint8_t rightAvg, uint8_t rightPeak);
void setTargetToTeam(int t);
void setSingleLed(int num, RgbColor col);

//How many equal slices the hue wheel is cut into for team colours
extern int team_hue_slices;

HslColor team_col(int t);

//-------------------------------------------------------------------------------------------------------

class NoAnim : public Animation {
public:
	void start(int param);
	void tick();
};

class Megamas : public Animation {
public:
	void start(int param);
	void tick();
};

class TimerTwinkle : public Animation {
public:
	void start(int param);
	void tick();
};

//A long, dim brightness wave travelling along the line.
class Swell : public Animation {
public:
	void start(int param);
	void tick();
};

//A mostly dark strip with a few slow warm glows rising and fading.
class Embers : public Animation {
public:
	void start(int param);
	void tick();
};

//A string of old coloured incandescent bulbs, a few of them flashers.
class OldLights : public Animation {
public:
	void start(int param);
	void tick();
};

class ColourPulse : public Animation {
public:
    void start(int param);
	void tick();
private:
    HsbColor col;
};

class TeamPulse : public Animation {
public:
    void start(int param);
	void tick();
private:
    HsbColor col;
	int frames_down;
};

class Counter : public Animation {
public:
    void start(int param);
	void tick();
private:
	int c;
};

class BuzzSweep : public Animation {
public:
    void start(int param);
	void tick();
	bool settled();
    uint8_t mode;
private:
    HslColor col;
};

class BuzzFlash : public Animation {
public:
    void start(int param);
	void tick();
	bool settled();
private:
    HslColor col;
	HsbColor flashcol;
	int flashnum, flashhold;
};

class BuzzCentre : public Animation {
public:
    void start(int param);
	void tick();
	bool settled();
private:
    HslColor col;
};

class BuzzRainbow : public Animation {
public:
    void start(int param);
	void tick();
	bool settled();
private:
    HslColor col;
    bool locked;
};

//Two comets fly in from the ends, collide in the middle, and burst out as the team colour.
class BuzzComet : public Animation {
public:
    void start(int param);
	void tick();
	bool settled();
private:
    float hue;
    bool done;
};

//Splats of colour land on the dark strip, starting well away from the team hue and converging on it.
class BuzzSplat : public Animation {
public:
    void start(int param);
	void tick();
	bool settled();
private:
    float hue;
};

//Solid team colour with a gentle twinkle, which every buzz animation hands over to once settled.
class TeamHold : public Animation {
public:
    void start(int param);
	void tick();
private:
    float hue;
};

#endif
