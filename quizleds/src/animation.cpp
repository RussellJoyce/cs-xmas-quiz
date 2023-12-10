#include <animation.h>
#include <settings.h>
#include <cmath>
#include <ledmapping.h>

NeoPixelBus<NeoRgbFeature, NeoWs2811Method> leds(NUM_LEDS, LED_PIN);

static HsbColor target[NUM_LEDS];
static HsbColor current[NUM_LEDS];
static int framenum = 0;

Megamas megamas;
NoAnim noanim;
ColourPulse colourpulse;
TeamPulse teampulse;
BuzzSweep buzzsweep;
BuzzFlash buzzflash;
BuzzCentre buzzcentre;
BuzzRainbow buzzrainbow;
Counter counter;
Animation* current_anim = &noanim;

void anim_init() {
    leds.Begin();
}

void anim_tick() {
    framenum++;
    if(current_anim != 0) 
        current_anim->tick();
}

void anim_set_anim(AnimID id, int param) {
    switch(id) {
        case NONE:
            current_anim = &noanim;
            break;
        case MEGAMAS:
            current_anim = &megamas;
            break;
        case COLOURPULSE:
            current_anim = &colourpulse;
            break;
        case TEAMPULSE:
            current_anim = &teampulse;
            break;
        case COUNTER:
            current_anim = &counter;
            break;
        case BUZZSWEEP1:
            current_anim = &buzzsweep;
            buzzsweep.mode = 0;
            break;
        case BUZZSWEEP2:
            current_anim = &buzzsweep;
            buzzsweep.mode = 1;
            break;
        case BUZZSWEEP3:
            current_anim = &buzzsweep;
            buzzsweep.mode = 2;
            break;
        case BUZZSWEEP4:
            current_anim = &buzzsweep;
            buzzsweep.mode = 3;
            break;
        case BUZZFLASH:
            current_anim = &buzzflash;
            break;
        case BUZZCENTRE:
            current_anim = &buzzcentre;
            break;
        case BUZZRAINBOW:
            current_anim = &buzzrainbow;
            break;
    }
    framenum = 0;
    if(current_anim != 0)
        current_anim->start(param);
}

AnimID buzz_anims[] = {BUZZSWEEP1, BUZZSWEEP3, BUZZSWEEP4, BUZZFLASH, BUZZCENTRE, BUZZRAINBOW};


//Play a buzzer animation. If animtoplay == -1 then cycles animations each buzz
//If greater than the total number of anims then play one randomly
void anim_buzz_team(int teamid, int animtoplay) {
    static int lastbuzz = -1;
    const int numbuzanims = sizeof(buzz_anims) / sizeof(AnimID);
    
    if(animtoplay < 0) {
        lastbuzz++;
        if(lastbuzz >= numbuzanims) lastbuzz = 0;
        animtoplay = lastbuzz;
    }
    if(animtoplay >= numbuzanims) {
        animtoplay = random(numbuzanims);
    }

    anim_set_anim(buzz_anims[animtoplay], teamid);
}


void setLEDs(RgbColor col) {
    leds.ClearTo(col);
	leds.Show();
}

void setLEDsNoAnim(RgbColor col) {
    current_anim = &noanim;
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


float fade(float to, float from, float amount) {
    if(to > from) {
        from += amount; 
        if(from > to) from = to;
    }
    if(to < from) {
        from -= amount;
        if(from < to) from = to;
    }
    return from;
}

void fade_current_to_target(float speed) {
    for(int i = 0; i < NUM_LEDS; i++) {
        current[i].B = fade(target[i].B, current[i].B, speed);
        current[i].H = fade(target[i].H, current[i].H, speed);
        current[i].S = fade(target[i].S, current[i].S, speed);
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
		target[i] = HsbColor(0, 1.0, 1.0);
		current[i] = HsbColor(0, 1.0, 1.0);
	}
    setLEDs(HslColor(0, 1.0, 0.5));
}

void Megamas::tick() {
	if(framenum > MEGAMAS_SPEED) {
		framenum = 0;
		for(int i = 0; i < MEGAMAS_NUMBER; i++) {
			switch(random(3)) {
				case 0:
					target[random(NUM_LEDS)] = HsbColor(0.0, 1.0, 1.0);
					break;
				case 1:
					target[random(NUM_LEDS)] = HsbColor(0.3, 1.0, 1.0);
					break;
				case 2:
					target[random(NUM_LEDS)] = HsbColor(0.6, 1.0, 1.0);
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
        } else if(framenum >= frames_up) {
            int progress = framenum - frames_up;
            this->col.B = 1.0 - (float(progress)*(1.0/float(frames_down)));
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

void Counter::start(int param) {
    this->c = param;
    for(int i = 0; i < NUM_LEDS; i++) {
        if(i < this->c) {
            leds.SetPixelColor(ledlookup[i], RgbColor(255, 255, 255));
        } else {
            leds.SetPixelColor(ledlookup[i], HsbColor(((float)rand()) / RAND_MAX, 1.0, 0.5));
        }
    }
    leds.Show();
}

void Counter::tick() {
    for(int i = this->c; i < NUM_LEDS; i++) {
        HsbColor col = leds.GetPixelColor(ledlookup[i]);
        col.B -= 0.01;
        if(col.B < 0) col.B = 0;
        leds.SetPixelColor(ledlookup[i], col);
    }
    leds.Show();
}

//-------------------------------------------------------------------------------------------------------

void BuzzSweep::start(int param) {
    clearLEDs();
    this->col = team_col(param);
}

inline int clamp(int i) {
    if(i < 0) return 0;
    if(i >= NUM_LEDS) return NUM_LEDS-1;
    return i;
}

int ledlookup_clamp(int i, bool random) {
    int clamped_i = clamp(i);
    return random ? ledlookup_rand[clamped_i] : ledlookup[clamped_i];
}

void BuzzSweep::tick() {
    static const int sweep_speed = 3;
    if(framenum < NUM_LEDS/sweep_speed + sweep_speed) {
        for(int i = 0; i < sweep_speed; i++) {
            switch(mode) {
                case 1: //Sweep from left
                    leds.SetPixelColor(ledlookup_clamp(framenum*sweep_speed+i, false), this->col);
                    break;
                case 2: //Sweep from right
                    leds.SetPixelColor(ledlookup_clamp((NUM_LEDS-1)-(framenum*sweep_speed+i), false), this->col);
                    break;
                case 3: //random 1
                    leds.SetPixelColor(ledlookup_clamp(framenum*sweep_speed+i, true), this->col);
                    break;
                default: //no lookup -> left and then right
                    leds.SetPixelColor(clamp(framenum*sweep_speed+i), this->col);
                    break;
            }
        }
        leds.Show();
    }
};

//-------------------------------------------------------------------------------------------------------


void BuzzFlash::start(int param) {
    clearLEDs();
    this->col = team_col(param);
    flashnum = 0;
    flashhold = 0;
}

void BuzzFlash::tick() {
    static const int numflashes = 5;
    static const int flashlen = 7;

    if(flashnum >= numflashes) {
        if(flashcol.B < 1.0) {
            flashcol.B += 0.01;
            if(flashcol.B > 0.95) flashcol.B = 1.0;
        }
    } else {
        if(flashhold == 0) {
            flashcol = HsbColor(((float)rand()) / RAND_MAX, 1.0, 1.0);
        } else {
            flashcol.B -= 0.1;
        }

        flashhold++;
        if(flashhold >= flashlen) {
            flashhold = 0;
            flashnum++;

            if(flashnum >= numflashes) {
                flashcol = HsbColor(col.H, 1.0, 0.0);
            }
        }
    }

    leds.ClearTo(flashcol);
    leds.Show();
}

//-------------------------------------------------------------------------------------------------------

void BuzzCentre::start(int param) {
    this->col = team_col(param);
	for(int i = 0; i < NUM_LEDS; i++) {
		target[i] = HsbColor(this->col.H, 1.0, 0);
		current[i] = HsbColor(this->col.H, 1.0, 0);
	}
    clearLEDs();
}

void BuzzCentre::tick() {
	if(framenum < NUM_LEDS/4) {
        for(int i = 0; i < 2; i++) {
            current[ledlookup_clamp(NUM_LEDS/2-(framenum*2), false)] = HsbColor(((float)rand()) / RAND_MAX, 1.0, 1.0);
            current[ledlookup_clamp(NUM_LEDS/2+(framenum*2+1), false)] = HsbColor(((float)rand()) / RAND_MAX, 1.0, 1.0);
        }
    } else if(framenum == (NUM_LEDS/4 + 20)) {
        for(int i = 0; i < NUM_LEDS; i++) {
            target[i] = HsbColor(this->col.H, 1.0, 1.0);
        }
    }
    
    fade_current_to_target(0.01);
    display_current();
}


//-------------------------------------------------------------------------------------------------------

void BuzzRainbow::start(int param) {
    this->col = team_col(param);
	clearLEDs();
}

void BuzzRainbow::tick() {
    if(framenum < 60) {
        for(int i = 0; i < NUM_LEDS; i++) {
            float huev = 0.005 * (i + framenum*3);
            if(huev > 1.0) huev = huev - 1.0;
            leds.SetPixelColor(ledlookup[i], HsbColor(huev, 1.0, 1.0));
        }
        leds.Show();
    } else {
        for(int i = 0; i < NUM_LEDS; i++) {
            HslColor cur = leds.GetPixelColor(i);

            if(fabs(cur.H - this->col.H) < 0.02) {
                cur.H = this->col.H;
            } else if(cur.H > this->col.H) {
                cur.H -= 0.02;
            } else {
                cur.H += 0.02;
            }

            leds.SetPixelColor(i, cur);
        }
        leds.Show();
    }
}
