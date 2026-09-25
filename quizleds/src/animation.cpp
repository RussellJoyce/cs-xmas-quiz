#include <animation.h>
#include <settings.h>
#include <cmath>
#include <ledmapping.h>

NeoPixelBus<NeoRgbFeature, NeoWs2811Method> leds(NUM_LEDS, LED_PIN);

static HsbColor target[NUM_LEDS];
static HsbColor current[NUM_LEDS];
static int framenum = 0;

Megamas megamas;
TimerTwinkle timertwinkle;
NoAnim noanim;
ColourPulse colourpulse;
TeamPulse teampulse;
BuzzSweep buzzsweep;
BuzzFlash buzzflash;
BuzzCentre buzzcentre;
BuzzRainbow buzzrainbow;
BuzzComet buzzcomet;
Counter counter;
Swell swell;
Embers embers;
OldLights oldlights;
Animation* current_anim = &noanim;

void anim_init() {
    leds.Begin();
}

void anim_tick() {
    if(current_anim != 0)
        current_anim->tick();
    framenum++;
}

void anim_set_anim(AnimID id, int param) {
    switch(id) {
        case NONE:
            current_anim = &noanim;
            break;
        case MEGAMAS:
            current_anim = &megamas;
            break;
        case TIMERTWINKLE:
            current_anim = &timertwinkle;
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
        case BUZZCOMET:
            current_anim = &buzzcomet;
            break;
        case SWELL:
            current_anim = &swell;
            break;
        case EMBERS:
            current_anim = &embers;
            break;
        case OLDLIGHTS:
            current_anim = &oldlights;
            break;
    }
    framenum = 0;
    if(current_anim != 0)
        current_anim->start(param);
}

AnimID buzz_anims[] = {BUZZSWEEP1, BUZZSWEEP3, BUZZSWEEP4, BUZZFLASH, BUZZCENTRE, BUZZRAINBOW, BUZZSWEEP2, BUZZCOMET};


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

void setSingleLed(int num, RgbColor col) {
    leds.SetPixelColor(ledlookup[num], col);
    leds.Show();
}

void setTargetToTeam(int t) {
    HslColor col = team_col(t);
    HsbColor colb = HsbColor(col.H, 1.0, 0.0);
    for(int i = 0; i < NUM_LEDS; i++) target[i] = colb;
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

#define TIMERTWINKLE_SPEED         4  // Speed of change
#define TIMERTWINKLE_NUMBER       20  // Number of LEDs to change
#define TIMERTWINKLE_TRANS_SPEED   0.02  // Transition speed

void TimerTwinkle::start(int param) {
	for(int i = 0; i < NUM_LEDS; i++) {
		target[i] = HsbColor(0, 1.0, 1.0);
		current[i] = HsbColor(0, 1.0, 1.0);
	}
    setLEDs(HslColor(0, 1.0, 0.5));
}

void TimerTwinkle::tick() {
	if(framenum > TIMERTWINKLE_SPEED) {
		framenum = 0;
		for(int i = 0; i < TIMERTWINKLE_NUMBER; i++) {
            current[random(NUM_LEDS)] = HsbColor(1.0, 1.0, 1.0);
		}
	}

    fade_current_hue_to_target(TIMERTWINKLE_TRANS_SPEED);
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
    //If param is >50 then we pulse very quickly, else more slowly
    HslColor teamcol = team_col(param >= 50 ? param - 50 : param);
    this->col = HsbColor(teamcol.H, 1.0, 0.0);
    this->frames_down = param >= 50 ? 10 : 120;
}

void TeamPulse::tick() {
    static const int frames_up = 10;

    if(framenum <= frames_up+frames_down) {
        if(framenum <= frames_up) {
            this->col.B = float(framenum) * (1.0 / float(frames_up));
        } else if(framenum >= frames_up) {
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
            leds.SetPixelColor(ledlookup[i], HsbColor(((float)rand()) / (float)RAND_MAX, 1.0, 0.5));
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
            flashcol = HsbColor(((float)rand()) / (float)RAND_MAX, 1.0, 1.0);
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
            current[ledlookup_clamp(NUM_LEDS/2-(framenum*2+i), false)] = HsbColor(((float)rand()) / (float)RAND_MAX, 1.0, 1.0);
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


//-------------------------------------------------------------------------------------------------------
// Worked in animation order (index 0..199 left to right along the line), and only mapped
// through ledlookup when drawn.

#define COMET_FRAMES       40     // Frames for the comets to reach the centre, about half a second
#define COMET_TAIL         0.8f   // Brightness each lit LED keeps per frame, which sets the tail length
#define COMET_HEAD_SAT     0.3f   // The head burns nearly white...
#define COMET_SAT_RECOVER  0.08f  // ...and regains its colour as it cools
#define COMET_BURST_SPEED  4.0f   // LEDs per frame for the burst front after impact

static float comet_b[NUM_LEDS];
static float comet_s[NUM_LEDS];

static void comet_ignite(int i) {
    comet_b[i] = 1.0f;
    comet_s[i] = COMET_HEAD_SAT;
}

void BuzzComet::start(int param) {
    this->hue = team_col(param).H;
    this->done = false;
    for(int i = 0; i < NUM_LEDS; i++) {
        comet_b[i] = 0.0f;
        comet_s[i] = 1.0f;
    }
    clearLEDs();
}

void BuzzComet::tick() {
    if(done) return;

    const float centre = (NUM_LEDS - 1) / 2.0f;

    //Everything already lit cools: it dims, and the white of the head gives way to the team colour
    for(int i = 0; i < NUM_LEDS; i++) {
        comet_b[i] *= COMET_TAIL;
        comet_s[i] += COMET_SAT_RECOVER;
        if(comet_s[i] > 1.0f) comet_s[i] = 1.0f;
    }

    if(framenum <= COMET_FRAMES) {
        //The comets accelerate in from both ends. Every LED passed over this frame is lit, not
        //just the one the head lands on, so the tail has no gaps once the comets are moving fast.
        float t0 = framenum > 0 ? (float) (framenum - 1) / COMET_FRAMES : 0.0f;
        float t1 = (float) framenum / COMET_FRAMES;
        int from = (int) (centre * t0 * t0);
        int to = (int) (centre * t1 * t1);
        for(int i = from; i <= to; i++) {
            comet_ignite(i);
            comet_ignite(NUM_LEDS - 1 - i);
        }
    } else {
        //The burst: a white front runs out from the centre and leaves the team colour behind it
        float r = (framenum - COMET_FRAMES) * COMET_BURST_SPEED;
        bool settled = r > centre;
        for(int i = 0; i < NUM_LEDS; i++) {
            float d = fabsf(i - centre);
            if(d <= r) {
                if(d > r - COMET_BURST_SPEED) comet_s[i] = COMET_HEAD_SAT;
                comet_b[i] = 1.0f;
            }
            if(comet_s[i] < 1.0f) settled = false;
        }
        //Solid team colour now, so there is nothing left to draw
        if(settled) done = true;
    }

    for(int i = 0; i < NUM_LEDS; i++) {
        leds.SetPixelColor(ledlookup[i], HsbColor(this->hue, comet_s[i], comet_b[i]));
    }
    leds.Show();
}


//-------------------------------------------------------------------------------------------------------
// Background animations
//
// dither() provides a simple temporal dithering to smooth out the bottom of the brightness range

static const float DITHER[4] = {0.125f, 0.625f, 0.375f, 0.875f};

static inline float dither(float b, int i) {
    return b + DITHER[(framenum + i) & 3] * (1.0f / 255.0f);
}

//-------------------------------------------------------------------------------------------------------

#define SWELL_HUE         0.08f   // Warm amber
#define SWELL_SAT         0.90f
#define SWELL_BASE        0.06f   // Middle of the brightness range
#define SWELL_AMP         0.06f   // So the wave runs between 0.0 and 0.12
#define SWELL_WAVELENGTH  120.0f  // LEDs. Longer than half the strip, so no repeat is visible
#define SWELL_PERIOD      1540    // Frames for one traverse, about 20 seconds
#define SWELL_FADEIN      77      // About a second

void Swell::start(int param) {
    clearLEDs();
}

void Swell::tick() {
    float gain = framenum < SWELL_FADEIN ? (float) framenum / (float) SWELL_FADEIN : 1.0f;
    float phase = (float) TWO_PI * ((float) (framenum % SWELL_PERIOD) / (float) SWELL_PERIOD);

    for(int i = 0; i < NUM_LEDS; i++) {
        float b = SWELL_BASE + SWELL_AMP * sinf((float) TWO_PI * ((float) i / SWELL_WAVELENGTH) - phase);
        leds.SetPixelColor(ledlookup[i], HsbColor(SWELL_HUE, SWELL_SAT, dither(b * gain, i)));
    }
    leds.Show();
}

//-------------------------------------------------------------------------------------------------------

#define EMBER_HUE         0.06f   // Warm, a touch redder than the swell
#define EMBER_HUE_SPREAD  0.04f   // Each ember is picked somewhere in HUE..HUE+SPREAD
#define EMBER_SAT         0.95f
#define EMBER_PEAK        0.18f
#define EMBER_SPEED       0.0022f // Per frame, so an ember takes about a second each way
#define EMBER_EVERY       26      // Frames between new embers, giving roughly six at a time

void Embers::start(int param) {
    for(int i = 0; i < NUM_LEDS; i++) {
        target[i] = HsbColor(EMBER_HUE, EMBER_SAT, 0.0);
        current[i] = HsbColor(EMBER_HUE, EMBER_SAT, 0.0);
    }
    //No fade in needed: the strip starts dark and fills as embers light, which is gentle
    //enough on its own.
    clearLEDs();
}

void Embers::tick() {
    if((framenum % EMBER_EVERY) == 0) {
        int i = random(NUM_LEDS);
        //The hue is set on both at once rather than faded to: the LED is dark at this point
        //so the change cannot be seen, and letting it drift would muddy the colour.
        float hue = EMBER_HUE + (float) random(1000) * (EMBER_HUE_SPREAD / 1000.0f);
        current[i].H = target[i].H = hue;
        current[i].S = target[i].S = EMBER_SAT;
        target[i].B = EMBER_PEAK;
    }

    //An ember that has finished rising is released, and fades back down to nothing.
    for(int i = 0; i < NUM_LEDS; i++) {
        if(target[i].B > 0.0f && current[i].B >= target[i].B - 0.0001f) {
            target[i].B = 0.0f;
        }
    }

    fade_current_to_target(EMBER_SPEED);

    for(int i = 0; i < NUM_LEDS; i++) {
        leds.SetPixelColor(i, HsbColor(current[i].H, current[i].S, dither(current[i].B, i)));
    }
    leds.Show();
}

//-------------------------------------------------------------------------------------------------------
// A string of old coloured incandescent bulbs. Worked in animation order, one bulb every
// OLDLIGHTS_SPACING LEDs with its neighbours as a dim halo, so the gaps between bulbs show.
// Most bulbs burn steadily; a few are flashers on their own irregular timers, and now and
// then a loose bulb stutters. Filaments warm up quickly and cool more slowly.

#define OLDLIGHTS_SPACING     4
#define OLDLIGHTS_BULBS       (NUM_LEDS / OLDLIGHTS_SPACING)
#define OLDLIGHTS_PEAK        0.5f    // Bulb brightness
#define OLDLIGHTS_HALO        0.12f   // Neighbouring LEDs, as a fraction of the bulb
#define OLDLIGHTS_SAT         0.85f   // Painted glass, not pure LED colours
#define OLDLIGHTS_WARM        0.12f   // Brightness gained per frame by a filament switching on
#define OLDLIGHTS_COOL        0.04f   // ...and lost per frame switching off
#define OLDLIGHTS_FLASHERS    6       // One bulb in this many is a flasher
#define OLDLIGHTS_STUTTER     400     // One frame in this many, on average, starts a loose bulb stuttering
#define OLDLIGHTS_FADEIN      77      // About a second

//Red, amber, green, blue, pink: the usual order on a string
static const float OLDLIGHTS_HUES[] = {0.0f, 0.08f, 0.33f, 0.62f, 0.9f};
#define OLDLIGHTS_NUM_HUES    (sizeof(OLDLIGHTS_HUES) / sizeof(OLDLIGHTS_HUES[0]))

static float bulb_level[OLDLIGHTS_BULBS];
static float bulb_gain[OLDLIGHTS_BULBS];     //No two bulbs are quite the same
static bool bulb_flasher[OLDLIGHTS_BULBS];
static bool bulb_on[OLDLIGHTS_BULBS];
static int bulb_timer[OLDLIGHTS_BULBS];      //Frames until a flasher next switches
static int bulb_stutter[OLDLIGHTS_BULBS];    //Frames of stuttering left

void OldLights::start(int param) {
    for(int b = 0; b < OLDLIGHTS_BULBS; b++) {
        bulb_level[b] = 0.0f;
        bulb_gain[b] = 0.8f + (float) random(200) / 1000.0f;
        bulb_flasher[b] = random(OLDLIGHTS_FLASHERS) == 0;
        bulb_on[b] = true;
        bulb_timer[b] = random(40, 160);
        bulb_stutter[b] = 0;
    }
    clearLEDs();
}

void OldLights::tick() {
    float gain = framenum < OLDLIGHTS_FADEIN ? (float) framenum / (float) OLDLIGHTS_FADEIN : 1.0f;

    if(random(OLDLIGHTS_STUTTER) == 0) {
        int b = random(OLDLIGHTS_BULBS);
        if(!bulb_flasher[b]) bulb_stutter[b] = random(15, 45);
    }

    for(int b = 0; b < OLDLIGHTS_BULBS; b++) {
        //A bimetallic flasher never keeps quite the same rhythm, so each period is picked afresh
        if(bulb_flasher[b] && --bulb_timer[b] <= 0) {
            bulb_on[b] = !bulb_on[b];
            bulb_timer[b] = bulb_on[b] ? random(60, 160) : random(40, 120);
        }

        bool lit = bulb_on[b];
        if(bulb_stutter[b] > 0) {
            bulb_stutter[b]--;
            lit = random(3) != 0;
        }

        if(lit) {
            bulb_level[b] += OLDLIGHTS_WARM;
            if(bulb_level[b] > 1.0f) bulb_level[b] = 1.0f;
        } else {
            bulb_level[b] -= OLDLIGHTS_COOL;
            if(bulb_level[b] < 0.0f) bulb_level[b] = 0.0f;
        }
    }

    for(int i = 0; i < NUM_LEDS; i++) {
        //Bulbs sit in the middle of their span, with a halo either side and the rest dark
        int b = i / OLDLIGHTS_SPACING;
        int offset = i % OLDLIGHTS_SPACING - OLDLIGHTS_SPACING / 2;
        float scale = offset == 0 ? 1.0f : (offset == 1 || offset == -1) ? OLDLIGHTS_HALO : 0.0f;
        float bright = OLDLIGHTS_PEAK * bulb_gain[b] * bulb_level[b] * scale * gain;
        float hue = OLDLIGHTS_HUES[b % OLDLIGHTS_NUM_HUES];
        leds.SetPixelColor(ledlookup[i], HsbColor(hue, OLDLIGHTS_SAT, dither(bright, i)));
    }
    leds.Show();
}
