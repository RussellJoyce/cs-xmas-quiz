/* Quiz LEDs Test
    Teensy 3.1 becomes a USB game controller with eight buttons, plus a serial device
    You must select 'Quiz Buzzer System' from the "Tools > USB Type" menu
    (Copy 'hardware' folder into Arduino installation folder to overwrite default Teensy types)

    If not using Arduino IDE, add "-DTEENSYDUINO=120" to compiler flags to fix FastLED ARM compile error
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
int command = 0;
int led;


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
        if (command == 0) {
            led = Serial.read();
            command = 1;
        }
        else {
            setLed(led, Serial.read());
            command = 0;
        }
    }
}
