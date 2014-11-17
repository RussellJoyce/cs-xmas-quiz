/* Basic USB Game Controller Test
   Teensy becomes a USB game controller with ten buttons, plus a serial device

   You must select 'Quiz Buzzer System' from the "Tools > USB Type" menu
   (Copy 'hardware' folder into Arduino installation folder to overwrite default Teensy types)

   Connecting each pin 0-9 to ground will set its corresponding button 1-10 as pressed
   LED will also flash, and test data will be echoed over serial port
*/

boolean led = false;

void setup() {
  pinMode(0, INPUT_PULLUP);
  pinMode(1, INPUT_PULLUP);
  pinMode(2, INPUT_PULLUP);
  pinMode(3, INPUT_PULLUP);
  pinMode(4, INPUT_PULLUP);
  pinMode(5, INPUT_PULLUP);
  pinMode(6, INPUT_PULLUP);
  pinMode(7, INPUT_PULLUP);
  pinMode(8, INPUT_PULLUP);
  pinMode(9, INPUT_PULLUP);

  pinMode(13, OUTPUT);

  Serial.begin(115200);

  Quiz.useManualSend(true);
}

void loop() {
  // read the digital inputs and set the buttons
  Quiz.button(1, !digitalRead(0));
  Quiz.button(2, !digitalRead(1));
  Quiz.button(3, !digitalRead(2));
  Quiz.button(4, !digitalRead(3));
  Quiz.button(5, !digitalRead(4));
  Quiz.button(6, !digitalRead(5));
  Quiz.button(7, !digitalRead(6));
  Quiz.button(8, !digitalRead(7));
  Quiz.button(9, !digitalRead(8));
  Quiz.button(10, !digitalRead(9));
  Quiz.send_now();

  Serial.println("Hello!");

  led = !led;
  digitalWrite(13, led);

  delay(200);
}
