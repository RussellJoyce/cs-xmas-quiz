/* Quiz Buzzer System
    Teensy 3.1 becomes a USB game controller with ten buttons, plus a serial device

    You must select 'Quiz Buzzer System' from the "Tools > USB Type" menu
    (Copy 'hardware' folder into Arduino installation folder to overwrite default Teensy types)
*/

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
#define LEDS  23 // LED string data

int ledCount = 0;

boolean buttons[] = {false, false, false, false, false, false, false, false};
boolean oldButtons[] = {false, false, false, false, false, false, false, false};
boolean leds[] = {false, false, false, false, false, false, false, false};
boolean reset = false;
boolean changed = true;

int count = 0;

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

    // Set up serial
    Serial.begin(115200);

    // Make game controller use manual event sending
    Quiz.useManualSend(true);

    // Send initial game controller buttons as off
    Quiz.button(1, false);
    Quiz.button(2, false);
    Quiz.button(3, false);
    Quiz.button(4, false);
    Quiz.button(5, false);
    Quiz.button(6, false);
    Quiz.button(7, false);
    Quiz.button(8, false);
    Quiz.send_now();
}

void loop() {
    oldButtons[0] = buttons[0];
    oldButtons[1] = buttons[1];
    oldButtons[2] = buttons[2];
    oldButtons[3] = buttons[3];
    oldButtons[4] = buttons[4];
    oldButtons[5] = buttons[5];
    oldButtons[6] = buttons[6];
    oldButtons[7] = buttons[7];

    buttons[0] = digitalRead(BTN1);
    buttons[1] = digitalRead(BTN2);
    buttons[2] = digitalRead(BTN3);
    buttons[3] = digitalRead(BTN4);
    buttons[4] = digitalRead(BTN5);
    buttons[5] = digitalRead(BTN6);
    buttons[6] = digitalRead(BTN7);
    buttons[7] = digitalRead(BTN8);

    changed = ((oldButtons[0] != buttons[0]) ||
               (oldButtons[1] != buttons[1]) ||
               (oldButtons[2] != buttons[2]) ||
               (oldButtons[3] != buttons[3]) ||
               (oldButtons[4] != buttons[4]) ||
               (oldButtons[5] != buttons[5]) ||
               (oldButtons[6] != buttons[6]) ||
               (oldButtons[7] != buttons[7]));

    if (changed) {
        Quiz.button(1, buttons[0]);
        Quiz.button(2, buttons[1]);
        Quiz.button(3, buttons[2]);
        Quiz.button(4, buttons[3]);
        Quiz.button(5, buttons[4]);
        Quiz.button(6, buttons[5]);
        Quiz.button(7, buttons[6]);
        Quiz.button(8, buttons[7]);
        Quiz.send_now(); 
    }

    leds[0] = buttons[0];
    leds[1] = buttons[1];
    leds[2] = buttons[2];
    leds[3] = buttons[3];
    leds[4] = buttons[4];
    leds[5] = buttons[5];
    leds[6] = buttons[6];
    leds[7] = buttons[7];

    digitalWrite(LED1, !leds[0]);
    digitalWrite(LED2, !leds[1]);
    digitalWrite(LED3, !leds[2]);
    digitalWrite(LED4, !leds[3]);
    digitalWrite(LED5, !leds[4]);
    digitalWrite(LED6, !leds[5]);
    digitalWrite(LED7, !leds[6]);
    digitalWrite(LED8, !leds[7]);

    //Serial.println("Hello!");

    // Blink the board LED
    ledCount ++;
    if (ledCount == 800) {
        digitalWrite(LEDB, true);
    }
    else if (ledCount == 1000) {
        digitalWrite(LEDB, false);
        ledCount = 0;
    }

    delay(2);


    // Code to test buzzer LEDs (alternates output)

    // leds[0] = (count == 0);
    // leds[1] = (count == 1);
    // leds[2] = (count == 2);
    // leds[3] = (count == 3);
    // leds[4] = (count == 4);
    // leds[5] = (count == 5);
    // leds[6] = (count == 6);
    // leds[7] = (count == 7);

    // digitalWrite(LED1, !leds[0]);
    // digitalWrite(LED2, !leds[1]);
    // digitalWrite(LED3, !leds[2]);
    // digitalWrite(LED4, !leds[3]);
    // digitalWrite(LED5, !leds[4]);
    // digitalWrite(LED6, !leds[5]);
    // digitalWrite(LED7, !leds[6]);
    // digitalWrite(LED8, !leds[7]);

    // count++;
    // delay(200);

    // if (count == 8)
    //     count = 0;

}
