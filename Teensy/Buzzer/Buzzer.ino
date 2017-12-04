/* Quiz Buzzer System
    Teensy 3.1 becomes a USB game controller with eight buttons, plus a serial device
    You must select 'Quiz Buzzer System' from the "Tools > USB Type" menu
    (Copy 'hardware' folder into Arduino installation folder to overwrite default Teensy types)

    If not using Arduino IDE, add "-DTEENSYDUINO=120" to compiler flags to fix FastLED ARM compile error
*/

#include "FastLED.h"
#include "boardconfig.h"
#include "ledmapping.h"
#include "library.h"
#include "twinkle.h"
#include "megamas.h"
#include "quizbuzz.h"
#include "commands.h"

#define BTN1  11
#define BTN2  15
#define BTN3  17
#define BTN4  10
#define BTN5   6
#define BTN6   2
#define BTN7  19
#define BTN8  21
#define BTN9   5
#define BTN10  1
#define LED1  14
#define LED2  16
#define LED3  12
#define LED4   8
#define LED5   4
#define LED6   0
#define LED7  18
#define LED8  20
#define LED9   7
#define LED10  3
#define LEDB  13 // On-board LED


Animation *currentAnim;
CRGB leds[NUM_LEDS];

volatile uint16_t buttons = 0;
volatile uint16_t oldButtons = 0;
volatile uint16_t buzzerLeds = 0;

const int ledPins[] = {LED1, LED2, LED3, LED4, LED5, LED6, LED7, LED8, LED9, LED10};

IntervalTimer updateTimer;

volatile uint8_t serialData;
volatile uint8_t serialCommand;
volatile uint8_t serialParam;

volatile int buzzerAnimationTeam = -1;
volatile int pointlessAnim = -1;
CRGB buzzerColour = CRGB::White;

Animation *animations[16];


inline void outputBuzzerLeds() {
    digitalWrite(LED1,  !bitRead(buzzerLeds, 0));
    digitalWrite(LED2,  !bitRead(buzzerLeds, 1));
    digitalWrite(LED3,  !bitRead(buzzerLeds, 2));
    digitalWrite(LED4,  !bitRead(buzzerLeds, 3));
    digitalWrite(LED5,  !bitRead(buzzerLeds, 4));
    digitalWrite(LED6,  !bitRead(buzzerLeds, 5));
    digitalWrite(LED7,  !bitRead(buzzerLeds, 6));
    digitalWrite(LED8,  !bitRead(buzzerLeds, 7));
    digitalWrite(LED9,  !bitRead(buzzerLeds, 8));
    digitalWrite(LED10, !bitRead(buzzerLeds, 9));
}

inline void outputBuzzerButtons() {
    Quiz.button(1,  bitRead(buttons, 0));
    Quiz.button(2,  bitRead(buttons, 1));
    Quiz.button(3,  bitRead(buttons, 2));
    Quiz.button(4,  bitRead(buttons, 3));
    Quiz.button(5,  bitRead(buttons, 4));
    Quiz.button(6,  bitRead(buttons, 5));
    Quiz.button(7,  bitRead(buttons, 6));
    Quiz.button(8,  bitRead(buttons, 7));
    Quiz.button(9,  bitRead(buttons, 8));
    Quiz.button(10, bitRead(buttons, 9));
    Quiz.send_now();
}

inline void setBuzzerLed(int led, boolean value) {
    if (bitRead(buzzerLeds, led) != value) {
        bitWrite(buzzerLeds, led, value);
        digitalWrite(ledPins[led], !value);
    }
}

inline void setBuzzerLedOn(int led) {
    if (!bitRead(buzzerLeds, led)) {
        bitSet(buzzerLeds, led);
        digitalWrite(ledPins[led], false);
    }
}

inline void setBuzzerLedOff(int led) {
    if (bitRead(buzzerLeds, led)) {
        bitClear(buzzerLeds, led);
        digitalWrite(ledPins[led], true);
    }
}

inline void setBuzzerLeds(uint16_t mask) {
    if (mask != buzzerLeds) {
        buzzerLeds = mask;
        outputBuzzerLeds();
    }
}

inline void switchAnimation(Animation *arg) {
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
            case LEDS_POINTW:
                setPointlessWrong();
                break;
            case LEDS_POINTC:
                setPointlessCorrect();
                break;
            case LED_ON:
                setBuzzerLedOn(serialParam);
                break;
            case LED_OFF:
                setBuzzerLedOff(serialParam);
                break;
            case LED_ALLON:
                setBuzzerLeds(0x03FF);
                break;
            case LED_ALLOFF:
                setBuzzerLeds(0x0000);
                break;
            case POINT_STATE:
                pointless_state(serialParam);
                break;
        }
    }

    // Output buttons
    oldButtons = buttons;
    bitWrite(buttons, 0, digitalRead(BTN1));
    bitWrite(buttons, 1, digitalRead(BTN2));
    bitWrite(buttons, 2, digitalRead(BTN3));
    bitWrite(buttons, 3, digitalRead(BTN4));
    bitWrite(buttons, 4, digitalRead(BTN5));
    bitWrite(buttons, 5, digitalRead(BTN6));
    bitWrite(buttons, 6, digitalRead(BTN7));
    bitWrite(buttons, 7, digitalRead(BTN8));
    bitWrite(buttons, 8, digitalRead(BTN9));
    bitWrite(buttons, 9, digitalRead(BTN10));

    if (buttons != oldButtons) {
        Quiz.button(1,  bitRead(buttons, 0));
        Quiz.button(2,  bitRead(buttons, 1));
        Quiz.button(3,  bitRead(buttons, 2));
        Quiz.button(4,  bitRead(buttons, 3));
        Quiz.button(5,  bitRead(buttons, 4));
        Quiz.button(6,  bitRead(buttons, 5));
        Quiz.button(7,  bitRead(buttons, 6));
        Quiz.button(8,  bitRead(buttons, 7));
        Quiz.button(9,  bitRead(buttons, 8));
        Quiz.button(10, bitRead(buttons, 9));
        Quiz.send_now();
    }
}


void setup() {
    // Set up button/LED pins
    pinMode(BTN1,  INPUT);
    pinMode(BTN2,  INPUT);
    pinMode(BTN3,  INPUT);
    pinMode(BTN4,  INPUT);
    pinMode(BTN5,  INPUT);
    pinMode(BTN6,  INPUT);
    pinMode(BTN7,  INPUT);
    pinMode(BTN8,  INPUT);
    pinMode(BTN9,  INPUT);
    pinMode(BTN10, INPUT);
    pinMode(LED1,  OUTPUT);
    pinMode(LED2,  OUTPUT);
    pinMode(LED3,  OUTPUT);
    pinMode(LED4,  OUTPUT);
    pinMode(LED5,  OUTPUT);
    pinMode(LED6,  OUTPUT);
    pinMode(LED7,  OUTPUT);
    pinMode(LED8,  OUTPUT);
    pinMode(LED9,  OUTPUT);
    pinMode(LED10, OUTPUT);
    pinMode(LEDB,  OUTPUT);
    pinMode(LED_DATA_PIN, OUTPUT);

    // Initialise animation array
    animations[1] = twinkle;
    animations[2] = megamas;

    // Flash some LEDs to say we're on
    setBuzzerLeds(0x03FF);
    delay(500);
    setBuzzerLeds(0x0000);

    // Set up serial (Teensy implicity uses full USB bandwidth of 12Mb/s)
    Serial.begin(0);

    // Make game controller use manual event sending
    Quiz.useManualSend(true);

    // Send initial game controller buttons as off
    outputBuzzerButtons();

    // Set buzzer LEDs to be off
    outputBuzzerLeds();

    // Initialise LED string
    FastLED.addLeds<WS2811, LED_DATA_PIN, GRB>(leds, NUM_LEDS);
    currentAnim = NULL;

    // Start update timer to interrupt every millisecond
    updateTimer.begin(updateTick, 1000);
}

void loop() {
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

