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
#define BTN9  22
#define BTN10 23
#define LED1  14
#define LED2  16
#define LED3  12
#define LED4   8
#define LED5   4
#define LED6   0
#define LED7  19
#define LED8  21
#define LEDB  13

int ledCount = 0;

boolean buttons[10];
boolean leds[8];
boolean reset = false;

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
    pinMode(BTN9, INPUT_PULLUP);
    pinMode(BTN10, INPUT_PULLUP);
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
}

void loop() {
    buttons[0] = digitalRead(BTN1);
    buttons[1] = digitalRead(BTN2);
    buttons[2] = digitalRead(BTN3);
    buttons[3] = digitalRead(BTN4);
    buttons[4] = digitalRead(BTN5);
    buttons[5] = digitalRead(BTN6);
    buttons[6] = digitalRead(BTN7);
    buttons[7] = digitalRead(BTN8);
    buttons[8] = digitalRead(BTN9);
    buttons[9] = digitalRead(BTN10);

    Quiz.button(1, buttons[0]);
    Quiz.button(2, buttons[1]);
    Quiz.button(3, buttons[2]);
    Quiz.button(4, buttons[3]);
    Quiz.button(5, buttons[4]);
    Quiz.button(6, buttons[5]);
    Quiz.button(7, buttons[6]);
    Quiz.button(8, buttons[7]);
    Quiz.button(9, buttons[8]);
    Quiz.button(10, buttons[9]);
    Quiz.send_now();

    reset = digitalRead(23);

    leds[0] = buttons[0] || (leds[0] && !reset);

    digitalWrite(10, !leds[0]);
    // digitalWrite(11, !digitalRead(1));
    // digitalWrite(12, !digitalRead(2));

    //Serial.println("Hello!");

    // Blink the board LED
    ledCount ++;
    if (ledCount == 980) {
        digitalWrite(LEDB, true);
    }
    else if (ledCount == 1000) {
        digitalWrite(LEDB, false);
        ledCount = 0;
    }

    delay(2);
}
