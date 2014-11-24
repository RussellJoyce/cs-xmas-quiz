/* Basic USB Game Controller Test
   Teensy becomes a USB game controller with ten buttons, plus a serial device

   You must select 'Quiz Buzzer System' from the "Tools > USB Type" menu
   (Copy 'hardware' folder into Arduino installation folder to overwrite default Teensy types)

   Connecting each pin 0-9 to ground will set its corresponding button 1-10 as pressed
   LED will also flash, and test data will be echoed over serial port
*/

boolean led = false;

boolean buttons[] = {false};
boolean buttonsPersistent[] = {false};
boolean reset = false;

void setup() {
  pinMode(0, INPUT);
  pinMode(1, INPUT);
  pinMode(2, INPUT);
  pinMode(3, INPUT);
  pinMode(4, INPUT);
  pinMode(5, INPUT);
  pinMode(6, INPUT);
  pinMode(7, INPUT);
  pinMode(8, INPUT);
  pinMode(9, INPUT);

  pinMode(23, INPUT_PULLUP);

  pinMode(10, OUTPUT);
  pinMode(11, OUTPUT);
  pinMode(12, OUTPUT);

  pinMode(13, OUTPUT);

  Serial.begin(115200);

  Quiz.useManualSend(true);
}

void loop() {
  buttons[0] = digitalRead(0);


  Quiz.button(1, buttons[0]);
  // Quiz.button(2, digitalRead(1));
  // Quiz.button(3, digitalRead(2));
  // Quiz.button(4, digitalRead(3));
  // Quiz.button(5, digitalRead(4));
  // Quiz.button(6, digitalRead(5));
  // Quiz.button(7, digitalRead(6));
  // Quiz.button(8, digitalRead(7));
  // Quiz.button(9, digitalRead(8));
  // Quiz.button(10, digitalRead(9));
  Quiz.send_now();

  reset = digitalRead(23);

  buttonsPersistent[0] = buttons[0] || (buttonsPersistent[0] && !reset);

  digitalWrite(10, !buttonsPersistent[0]);
  // digitalWrite(11, !digitalRead(1));
  // digitalWrite(12, !digitalRead(2));

  //Serial.println("Hello!");

  led = !led;
  digitalWrite(13, led);

  delay(100);
}
