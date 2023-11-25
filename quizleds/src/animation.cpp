#include <animation.h>
#include <settings.h>
#include <cmath>
#include <ledmapping.h>

NeoPixelBus<NeoGrbFeature, NeoWs2812xMethod> leds(NUM_LEDS, LED_PIN);

static HslColor target[NUM_LEDS];
static HslColor current[NUM_LEDS];
static int framenum = 0;

Megamas megamas;
NoAnim noanim;
ColourPulse colourpulse;
TeamPulse teampulse;
BuzzSweep buzzsweep;
Animation& current_anim = noanim;


void anim_init() {
    leds.Begin();
}

void anim_tick() {
    framenum++;
    current_anim.tick();
}

void anim_set_anim(AnimID id, int param) {
    switch(id) {
        case NONE:
            current_anim = noanim;
            break;
        case MEGAMAS:
            current_anim = megamas;
            break;
        case COLOURPULSE:
            current_anim = colourpulse;
            break;
        case TEAMPULSE:
            current_anim = teampulse;
            break;
        case BUZZSWEEP1:
            current_anim = buzzsweep;
            buzzsweep.mode = 0;
            break;
        case BUZZSWEEP2:
            current_anim = buzzsweep;
            buzzsweep.mode = 1;
            break;
        case BUZZSWEEP3:
            current_anim = buzzsweep;
            buzzsweep.mode = 2;
            break;
        case BUZZSWEEP4:
            current_anim = buzzsweep;
            buzzsweep.mode = 3;
            break;
        case BUZZSWEEP5:
            current_anim = buzzsweep;
            buzzsweep.mode = 4;
            break;
    }
    framenum = 0;
    current_anim.start(param);
}

void anim_buzz_team(int teamid) {
    switch(random(5)) {
        case 0: anim_set_anim(BUZZSWEEP1, teamid); break;
        case 1: anim_set_anim(BUZZSWEEP2, teamid); break;
        case 2: anim_set_anim(BUZZSWEEP3, teamid); break;
        case 3: anim_set_anim(BUZZSWEEP4, teamid); break;
        case 4: anim_set_anim(BUZZSWEEP5, teamid); break;
        default:
            anim_set_anim(BUZZSWEEP2, teamid);
    }
}


void setLEDs(RgbColor col) {
    leds.ClearTo(col);
	leds.Show();
}

void setLEDsNoAnim(RgbColor col) {
    current_anim = noanim;
    setLEDs(col);
}

void clearLEDs() {
	setLEDs(RgbColor(0, 0, 0));
}

HslColor team_col(int t) {
    //Each team is 10% of the hue wheel, looping at 10.
    return HslColor(std::fmod(0.1 * t, 1.0) , 1.0, 0.5);
}

bool fadeLeds(int speed) {
    const int threshold = 10;
    bool any_on = false;
	for(auto i = 0; i < NUM_LEDS; i++) {
		RgbColor c = leds.GetPixelColor(i);
        if(c.R > threshold || c.B > threshold || c.G > threshold) any_on = true;
		c.Darken(speed);
		leds.SetPixelColor(i, c);
	}
	leds.Show();
    return any_on;
}

void fadeLEDsOut(int speed) {
    while(fadeLeds(speed));
    clearLEDs();
}

void display_current() {
    for(int i = 0; i < NUM_LEDS; i++) {
        leds.SetPixelColor(i, current[i]);
    }
    leds.Show();
}

void fade_current_hue_to_target(float speed) {
    for(int i = 0; i < NUM_LEDS; i++) {
		if(current[i].H < target[i].H) {
			if(target[i].H - current[i].H < speed) {
				current[i].H = target[i].H;
			} else if(current[i].H < (1.0-speed)) {
				current[i].H += speed;
			} else {
				current[i].H = 1.0;
			}
		}

		if(current[i].H > target[i].H) {
			if(current[i].H - target[i].H < speed) {
				current[i].H = target[i].H;
			} else if(current[i].H > speed) {
				current[i].H -= speed;
			} else {
				current[i].H = 0.0;
			}
		}
	}
}


void set_music_levels(uint8_t leftAvg, uint8_t leftPeak, uint8_t rightAvg, uint8_t rightPeak) {
	for (int i = 0; i < NUM_LEDS/2; i++) {
		if (i < rightAvg)
			leds.SetPixelColor(ledlookup[i], RgbColor(0, 255, 0));
		else if (i < rightPeak)
            leds.SetPixelColor(ledlookup[i], RgbColor(255, 0, 0));
		else
            leds.SetPixelColor(ledlookup[i], RgbColor(0, 0, 0));
	}

	for (int i = NUM_LEDS/2; i < NUM_LEDS; i++) {
		if (i >= NUM_LEDS-leftAvg)
            leds.SetPixelColor(ledlookup[i], RgbColor(0, 255, 0));
		else if (i >= NUM_LEDS-leftPeak)
            leds.SetPixelColor(ledlookup[i], RgbColor(255, 0, 0));
		else
            leds.SetPixelColor(ledlookup[i], RgbColor(0, 0, 0));
	}

	leds.Show();
}


Animation::Animation() {}
Animation::~Animation() {}


//-------------------------------------------------------------------------------------------------------

void NoAnim::start(int param) {
    clearLEDs();
};
void NoAnim::tick() {};

//-------------------------------------------------------------------------------------------------------

#define MEGAMAS_SPEED         4  // Speed of change
#define MEGAMAS_NUMBER       10  // Number of LEDs to change
#define TRANS_SPEED   0.01  // Transition speed

void Megamas::start(int param) {
	for(int i = 0; i < NUM_LEDS; i++) {
		target[i] = HslColor(0, 1.0, 0.5);
		current[i] = HslColor(0, 1.0, 0.5);
	}
    setLEDs(HslColor(0, 1.0, 0.5));
}

void Megamas::tick() {
	if(framenum > MEGAMAS_SPEED) {
		framenum = 0;
		for(int i = 0; i < MEGAMAS_NUMBER; i++) {
			switch(random(3)) {
				case 0:
					target[random(NUM_LEDS)] = HslColor(0.0, 1.0, 0.5);
					break;
				case 1:
					target[random(NUM_LEDS)] = HslColor(0.3, 1.0, 0.5);
					break;
				case 2:
					target[random(NUM_LEDS)] = HslColor(0.6, 1.0, 0.5);
					break;
			}
		}
	}

    fade_current_hue_to_target(TRANS_SPEED);
    display_current();
}

//-------------------------------------------------------------------------------------------------------

void ColourPulse::start(int param) {
    clearLEDs();
    switch(param) {
        case 0:
            this->col = HsbColor(0.0, 0.0, 0.0); //White
            break;
        case 1:
            this->col = HsbColor(0.0, 1.0, 0.0); //Red
            break;
        case 2:
            this->col = HsbColor(0.35, 1.0, 0.0); //Green
            break;
        default:
            this->col = HsbColor(0.0, 0.0, 0.0); //White
            break;
    }
};

void ColourPulse::tick() {
    static const int frames_up = 10;
    static const int frames_down = 120;

    if(framenum <= frames_up+frames_down) {
        if(framenum <= frames_up) {
            this->col.B = float(framenum) * (1.0 / float(frames_up));
        } else if(framenum >= frames_down+frames_up) {
            this->col.B = 1.0 - (float(framenum-frames_up)*(1.0/float(frames_down)));
        }
        leds.ClearTo(this->col);
        leds.Show();
    }
};

//-------------------------------------------------------------------------------------------------------

void TeamPulse::start(int param) {
    clearLEDs();
    HslColor teamcol = team_col(param);
    this->col = HsbColor(teamcol.H, 1.0, 0.0);
}

void TeamPulse::tick() {
    static const int frames_up = 10;
    static const int frames_down = 120;

    if(framenum <= frames_up+frames_down) {
        if(framenum <= frames_up) {
            this->col.B = float(framenum) * (1.0 / float(frames_up));
        } else if(framenum >= frames_down+frames_up) {
            this->col.B = 1.0 - (float(framenum-frames_up)*(1.0/float(frames_down)));
        }
        leds.ClearTo(this->col);
        leds.Show();
    }
};

//-------------------------------------------------------------------------------------------------------

void BuzzSweep::start(int param) {
    clearLEDs();
    this->col = team_col(param);
}

void BuzzSweep::tick() {
    if(framenum < NUM_LEDS) {
        switch(mode) {
            case 1: //Sweep from left
                leds.SetPixelColor(ledlookup[framenum], this->col);
                break;
            case 2: //Sweep from right
                leds.SetPixelColor(ledlookup[(NUM_LEDS-1)-framenum], this->col);
                break;
            case 3: //random 1
                leds.SetPixelColor(ledlookup_rand[framenum], this->col);
                break;
            case 4: //random 2
                leds.SetPixelColor(ledlookup_rand[(NUM_LEDS-1)-framenum], this->col);
                break;
            default: //no lookup, will come from both sides
                leds.SetPixelColor(framenum, this->col);
                break;
        }
        leds.Show();
    }
};

//-------------------------------------------------------------------------------------------------------
