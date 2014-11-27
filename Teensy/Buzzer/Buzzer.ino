/* Quiz Buzzer System
    Teensy 3.1 becomes a USB game controller with eight buttons, plus a serial device
    You must select 'Quiz Buzzer System' from the "Tools > USB Type" menu
    (Copy 'hardware' folder into Arduino installation folder to overwrite default Teensy types)

    If not using Arduino IDE, add "-DTEENSYDUINO=120" to compiler flags to fix FastLED ARM compile error
*/

#include "FastLED.h"
#include "boardconfig.h"
#include "library.h"
#include "twinkle.h"
#include "quizbuzz.h"
#include "commands.h"

#define BTN1  11
#define BTN2  15
#define BTN3  17
#define BTN4  10
#define BTN5   6
#define BTN6   2
#define BTN7  18
#define BTN8  20
#define LED1  14
#define LED2  16
#define LED3  12
#define LED4   8
#define LED5   4
#define LED6   0
#define LED7  19
#define LED8  21
#define LEDB  13 // On-board LED
#define LEDS  23 // LED string data pin


Animation *currentAnim;
CRGB leds[NUM_LEDS];

volatile uint8_t buttons = 0;
volatile uint8_t oldButtons = 0;
volatile uint8_t buzzerLeds = 0;

const int ledPins[] = {LED1, LED2, LED3, LED4, LED5, LED6, LED7, LED8};

IntervalTimer updateTimer;
volatile uint8_t serialData;
volatile uint8_t serialData2;
volatile uint8_t serialCommand;
volatile uint8_t serialParam;
volatile boolean serialSecond = false;

Animation *animations[8];


inline void outputBuzzerLeds() {
    digitalWrite(LED1, !bitRead(buzzerLeds, 0));
    digitalWrite(LED2, !bitRead(buzzerLeds, 1));
    digitalWrite(LED3, !bitRead(buzzerLeds, 2));
    digitalWrite(LED4, !bitRead(buzzerLeds, 3));
    digitalWrite(LED5, !bitRead(buzzerLeds, 4));
    digitalWrite(LED6, !bitRead(buzzerLeds, 5));
    digitalWrite(LED7, !bitRead(buzzerLeds, 6));
    digitalWrite(LED8, !bitRead(buzzerLeds, 7));
}

inline void outputBuzzerButtons() {
    Quiz.button(1, bitRead(buttons, 0));
    Quiz.button(2, bitRead(buttons, 1));
    Quiz.button(3, bitRead(buttons, 2));
    Quiz.button(4, bitRead(buttons, 3));
    Quiz.button(5, bitRead(buttons, 4));
    Quiz.button(6, bitRead(buttons, 5));
    Quiz.button(7, bitRead(buttons, 6));
    Quiz.button(8, bitRead(buttons, 7));
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

inline void setBuzzerLeds(uint8_t mask) {
    if (mask != buzzerLeds) {
        buzzerLeds = mask;
        outputBuzzerLeds();
    }
}

void switchAnimation(Animation *arg) {
    currentAnim = arg;

    if (currentAnim != NULL) {
        currentAnim->start();
    }
    else {
        clearLEDs();
    }
}


void updateTick() {
    // Handle any data on serial port
    if (Serial.available()) {
        serialData = Serial.read();
        if (!serialSecond) {
            serialCommand = serialData & 0xF0; // Set command to be high 4 bits (0 to F)
            serialParam = serialData & 0x07;   // Set parameter to be low 3 bits (0 to 7)

            if (serialCommand == LEDS_ANIM) {
                switchAnimation(animations[serialParam]);
            }
            else if (serialCommand == LEDS_TEAM) {
                play_buzz_anim(serialParam);
            }
            else if (serialCommand == LEDS_TEAMG) {
                set_team_colour(serialParam, CRGB::Green);
            }
            else if (serialCommand == LEDS_TEAMR) {
                set_team_colour(serialParam, CRGB::Red);
            }
            else if (serialCommand == LED_ON) {
                setBuzzerLedOn(serialParam);
            }
            else if (serialCommand == LED_OFF) {
                setBuzzerLedOff(serialParam);
            }
            else if (serialCommand == LED_SET) {
                serialSecond = true;
            }
        }
        else {
            if (serialCommand == LED_SET) {
                setBuzzerLeds(serialData);
            }
            serialSecond = false;
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

    if (buttons != oldButtons) {
        Quiz.button(1, bitRead(buttons, 0));
        Quiz.button(2, bitRead(buttons, 1));
        Quiz.button(3, bitRead(buttons, 2));
        Quiz.button(4, bitRead(buttons, 3));
        Quiz.button(5, bitRead(buttons, 4));
        Quiz.button(6, bitRead(buttons, 5));
        Quiz.button(7, bitRead(buttons, 6));
        Quiz.button(8, bitRead(buttons, 7));
        Quiz.send_now();
    }
}


void setup() {
    // Set up button/LED pins
    pinMode(BTN1, INPUT);
    pinMode(BTN2, INPUT);
    pinMode(BTN3, INPUT);
    pinMode(BTN4, INPUT);
    pinMode(BTN5, INPUT);
    pinMode(BTN6, INPUT);
    pinMode(BTN7, INPUT);
    pinMode(BTN8, INPUT);
    pinMode(LED1, OUTPUT);
    pinMode(LED2, OUTPUT);
    pinMode(LED3, OUTPUT);
    pinMode(LED4, OUTPUT);
    pinMode(LED5, OUTPUT);
    pinMode(LED6, OUTPUT);
    pinMode(LED7, OUTPUT);
    pinMode(LED8, OUTPUT);
    pinMode(LEDB, OUTPUT);

    // Initialise animation array
    animations[1] = twinkle;

    // Set up serial (Teensy implicity uses full USB bandwidth of 12Mb/s)
    Serial.begin(0);

    // Make game controller use manual event sending
    Quiz.useManualSend(true);

    // Send initial game controller buttons as off
    outputBuzzerButtons();

    // Set buzzer LEDs to be off
    outputBuzzerLeds();

    // Initialise LED string
    FastLED.addLeds<WS2811, LED_DATA_PIN, RGB>(leds, NUM_LEDS);
    currentAnim = NULL;

    // Start update timer to interrupt every millisecond
    updateTimer.begin(updateTick, 1000);
}

void loop() {
    if (currentAnim != NULL) {
        currentAnim->tick();
    }
}

