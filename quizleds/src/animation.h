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
    NONE, MEGAMAS, TIMERTWINKLE, COLOURPULSE, TEAMPULSE, COUNTER, BUZZSWEEP1, BUZZSWEEP2, BUZZSWEEP3, BUZZSWEEP4, BUZZFLASH, BUZZCENTRE, BUZZRAINBOW
} AnimID;

void anim_init();
void anim_tick();
void anim_set_anim(AnimID id, int param);
void clearLEDs();
void setLEDs(RgbColor col);
void setLEDsNoAnim(RgbColor col);
void anim_buzz_team(int teamid, int animtoplay = -1);
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

class TimerTwinkle : public Animation {
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
    uint8_t mode;
private:
    HslColor col;
};

class BuzzFlash : public Animation {
public:
    void start(int param);
	void tick();
private:
    HslColor col;
	HsbColor flashcol;
	int flashnum, flashhold;
};

class BuzzCentre : public Animation {
public:
    void start(int param);
	void tick();
private:
    HslColor col;
};

class BuzzRainbow : public Animation {
public:
    void start(int param);
	void tick();
private:
    HslColor col;
};

#endif
