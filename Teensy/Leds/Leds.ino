#include "FastLED.h"

#define NUM_LEDS 100

#define DATA_PIN 23

CRGB leds[NUM_LEDS];

int rainbowCount = 0;

void setup() { 
    FastLED.addLeds<WS2811, DATA_PIN, RGB>(leds, NUM_LEDS);
    int v = 0;
    for (int j = 0; j < NUM_LEDS; j++) {
        leds[j].setRGB(v, v, v);
    }
    FastLED.show();
}

void loop() { 
    // Rainbow
    for (int j = 0; j < NUM_LEDS; j++) {
        leds[j].setHue((rainbowCount % 255) + (j * (255 / NUM_LEDS)));
    }

    // static int frame = 0;
    // frame++;

    // for(int i = 0; i < NUM_LEDS; i++) {
    //  if(frame % 2) {
    //      leds[i].setRGB(255,0,0);
    //  } else {
    //      leds[i].setRGB(0,255,0);
    //  }

    // }

    FastLED.show();
    delay(20);

    rainbowCount++;
}
