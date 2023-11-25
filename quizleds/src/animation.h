#ifndef SRC_ANIMATION_H_
#define SRC_ANIMATION_H_

#include <NeoPixelBus.h>

/*
Base animation class.
*/
class Animation {
public:
	Animation();
	virtual void tick() = 0;
	virtual void start(int param) = 0;
	virtual ~Animation();
};

typedef enum {
    NONE, MEGAMAS, COLOURPULSE, TEAMPULSE, BUZZSWEEP1, BUZZSWEEP2, BUZZSWEEP3, BUZZSWEEP4, BUZZSWEEP5
} AnimID;

void anim_init();
void anim_tick();
void anim_set_anim(AnimID id, int param);
void clearLEDs();
void setLEDs(RgbColor col);
void setLEDsNoAnim(RgbColor col);
void anim_buzz_team(int teamid);
void set_music_levels(uint8_t leftAvg, uint8_t leftPeak, uint8_t rightAvg, uint8_t rightPeak);

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
};

class BuzzSweep : public Animation {
public:
    void start(int param);
	void tick();
    uint8_t mode;
private:
    HslColor col;
};

#endif
