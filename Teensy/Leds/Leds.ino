/* Quiz LEDs Test
    Teensy 3.1 becomes a USB game controller with ten buttons, plus a serial device

    You must select 'Quiz Buzzer System' from the "Tools > USB Type" menu
    (Copy 'hardware' folder into Arduino installation folder to overwrite default Teensy types)

    If not using Arduino IDE, add "-DTEENSYDUINO=120" to compiler flags
*/

#include <FastLED.h>
#include "boardconfig.h"
#include "library.h"
#include "twinkle.h"
#include "quizbuzz.h"
#include "commands.h"


Animation *currentAnim;
CRGB leds[NUM_LEDS];
int serialData;


void leds_off() {
    clearLEDs();
    currentAnim = NULL;
}

void switch_animation(Animation *arg) {
    currentAnim = arg;
    currentAnim->start();
}


void setup() {
    FastLED.addLeds<WS2811, LED_DATA_PIN, RGB>(leds, NUM_LEDS);
    currentAnim = NULL;
    Serial.begin(0);
}


void loop() {
    if (Serial.available()) {
        switch (Serial.read()) {
            case LEDS_OFF:
                leds_off();
                break;
            case LEDS_TWINKLE:
                switch_animation(twinkle);
                break;
            case LEDS_TEAM1:
                play_buzz_anim(1);
                break;
            case LEDS_TEAM2:
                play_buzz_anim(2);
                break;
            case LEDS_TEAM3:
                play_buzz_anim(3);
                break;
            case LEDS_TEAM4:
                play_buzz_anim(4);
                break;
            case LEDS_TEAM5:
                play_buzz_anim(5);
                break;
            case LEDS_TEAM6:
                play_buzz_anim(6);
                break;
            case LEDS_TEAM7:
                play_buzz_anim(7);
                break;
            case LEDS_TEAM8:
                play_buzz_anim(8);
                break;
            case LEDS_TEAM1R:
                set_team_colour(1, CRGB::Red);
                break;
            case LEDS_TEAM2R:
                set_team_colour(2, CRGB::Red);
                break;
            case LEDS_TEAM3R:
                set_team_colour(3, CRGB::Red);
                break;
            case LEDS_TEAM4R:
                set_team_colour(4, CRGB::Red);
                break;
            case LEDS_TEAM5R:
                set_team_colour(5, CRGB::Red);
                break;
            case LEDS_TEAM6R:
                set_team_colour(6, CRGB::Red);
                break;
            case LEDS_TEAM7R:
                set_team_colour(7, CRGB::Red);
                break;
            case LEDS_TEAM8R:
                set_team_colour(8, CRGB::Red);
                break;
            case LEDS_TEAM1G:
                set_team_colour(1, CRGB::Green);
                break;
            case LEDS_TEAM2G:
                set_team_colour(2, CRGB::Green);
                break;
            case LEDS_TEAM3G:
                set_team_colour(3, CRGB::Green);
                break;
            case LEDS_TEAM4G:
                set_team_colour(4, CRGB::Green);
                break;
            case LEDS_TEAM5G:
                set_team_colour(5, CRGB::Green);
                break;
            case LEDS_TEAM6G:
                set_team_colour(6, CRGB::Green);
                break;
            case LEDS_TEAM7G:
                set_team_colour(7, CRGB::Green);
                break;
            case LEDS_TEAM8G:
                set_team_colour(8, CRGB::Green);
                break;
        }
    }

    if (currentAnim != NULL) {
        currentAnim->tick();
    }
}
