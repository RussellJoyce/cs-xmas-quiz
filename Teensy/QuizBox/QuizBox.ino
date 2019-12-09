/* Quiz Buzzer System
    Teensy 3.1 becomes a USB serial device for controlling the quiz LEDs string.
    You must select 'Serial' from the "Tools > USB Type" menu.

    If not using Arduino IDE, add "-DTEENSYDUINO=120" to compiler flags to fix FastLED ARM compile error.
*/

#include "FastLED.h"
#include "boardconfig.h"
#include "ledmapping.h"
#include "library.h"
#include "twinkle.h"
#include "megamas.h"
#include "quizbuzz.h"
#include "commands.h"

#define LEDB  13 // On-board LED


Animation *currentAnim;
CRGB leds[NUM_LEDS];

volatile uint8_t serialData;
volatile uint8_t serialCommand;
volatile uint8_t serialParam;

volatile int buzzerAnimationTeam = -1;
volatile int pointlessAnim = -1;
CRGB buzzerColour = CRGB::White;

Animation *animations[16];

int data_count = 0;
uint8_t data[4];


inline void switchAnimation(Animation *arg) {
    if (arg != NULL && currentAnim == arg)
        return;

    currentAnim = arg;

    if (currentAnim != NULL) {
        currentAnim->start();
    }
    else {
        clearLEDs();
    }
}

inline void playBuzzerAnimation(int team) {
    currentAnim = NULL;
    pointlessAnim = -1;
    buzzerAnimationTeam = team;
}

inline void setPointlessWrong() {
    currentAnim = NULL;
    buzzerAnimationTeam = -1;
    pointlessAnim = 1;
}

inline void setPointlessCorrect() {
    currentAnim = NULL;
    buzzerAnimationTeam = -1;
    pointlessAnim = 2;
}

inline void setTestOn(int team) {
    if (team < 0 || team >= NUM_TEAMS) return;
    for (int i = team; i < NUM_LEDS; i+=NUM_TEAMS) leds[ledlookup[i]] = teamcol[team];
    FastLED.show();
}

inline void setTestOff(int team) {
    if (team < 0 || team >= NUM_TEAMS) return;
    for (int i = team; i < NUM_LEDS; i+=NUM_TEAMS) leds[ledlookup[i]] = CRGB::Black;
    FastLED.show();
}


void updateTick() {
    // Handle any data on serial port
    if (Serial.available()) {
        serialData = Serial.read();
        serialCommand = serialData & 0xF0; // Set command to be high 4 bits (0x to Fx)
        serialParam = serialData & 0x0F;   // Set parameter to be low 4 bits (x0 to xF)

        if (serialData == CANCEL) {
            data_count = 0;
            return;
        }

        if (data_count == 0) {
            switch (serialCommand) {
                case LEDS_ANIM:
                    switchAnimation(animations[serialParam]);
                    break;
                case LEDS_TEAM:
                    playBuzzerAnimation(serialParam);
                    break;
                case LEDS_TEAMC:
                    set_string_team_colour(serialParam);
                    break;
                case LEDS_COL:
                    set_string_colour(serialParam);
                    break;
                case LEDS_TESTON:
                    setTestOn(serialParam);
                    break;
                case LEDS_TESTOFF:
                    setTestOff(serialParam);
                    break;
                case LEDS_TEAMPUL:
                    pulse_team_colour(serialParam);
                    break;
                case LEDS_POINTW:
                    setPointlessWrong();
                    break;
                case LEDS_POINTC:
                    setPointlessCorrect();
                    break;
                case LEDS_POINT_STATE:
                    pointless_state(serialParam);
                    break;
                case LEDS_MUSIC_LEVELS:
                    data_count = 1;
                    break;
            }
        }
        else {
            data[data_count - 1] = serialData;
            if (data_count > 3) {
                data_count = 0;
                set_music_levels(data[0], data[1], data[2], data[3]);
            }
            else
                data_count++;
        }
    }
}


void setup() {
    // Set up LED pins
    pinMode(LEDB,  OUTPUT);
    pinMode(LED_DATA_PIN, OUTPUT);

    // Initialise animation array
    animations[1] = twinkle;
    animations[2] = megamas;

    // Flash LED to say we're on
    digitalWrite(LEDB, true);
    delay(250);
    digitalWrite(LEDB, false);
    delay(250);
    digitalWrite(LEDB, true);

    // Set up serial (Teensy implicity uses full USB bandwidth of 12Mb/s)
    Serial.begin(0);

    // Initialise LED string
    FastLED.addLeds<WS2811, LED_DATA_PIN, RGB>(leds, NUM_LEDS);
    currentAnim = NULL;
}

void loop() {
    updateTick();

    if (currentAnim != NULL) {
        currentAnim->tick();
    }
    else if (buzzerAnimationTeam != -1) {
        play_buzz_anim(buzzerAnimationTeam);
        buzzerAnimationTeam = -1;
    }
    else if (pointlessAnim == 1) {
        play_pointless_wrong();
        pointlessAnim = -1;
    }
    else if (pointlessAnim == 2) {
        play_pointless_correct();
        pointlessAnim = -1;
    }
}

