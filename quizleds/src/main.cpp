#include <Arduino.h>
#include <settings.h>
#include <animation.h>
#include <web.h>

void setup() {
	Serial.begin(115200);
	while(!Serial);

	if(SLOW_BOOT) {
		delay(5000);
		Serial.println("Booting...");
	}

	anim_init();

	if(!OFFLINE_MODE) {
		connectWifi();
	} else {
		anim_set_anim(MEGAMAS, 0);
	}
}

void single_led(int num) {
	Serial.println(num);
	setLEDsNoAnim(RgbColor(0,0,0));
	setSingleLed(num, RgbColor(255,255,255));
}

void loop() {
	static volatile unsigned long next_frame_time = 0;

	//Tick the current animation
	unsigned long current_time = millis();
	if(current_time >= next_frame_time) {
		anim_tick();
		next_frame_time = current_time + MILLIS_PER_FRAME;
	}

	//Handle simple debug UART interface
	static int singleled = 0; 
	static int serial_mode = 0; //what do the number keys do. 0 = buzz, 1 = animation, 2 = team colour
	static int target_team = 0; //what team to buzz for
	if(Serial.available()) {
		char c = Serial.read();
		if(c <= '9' && c >= '0') {
			char num = c - '0';
			switch (serial_mode) {
				case 0: //Buzz
					Serial.printf("Buzz %d\n", num);
					anim_buzz_team(target_team, num);
					break;
				case 1: //Animation
					Serial.printf("Anim %d\n", num);
					anim_set_ambient(num);
					break;
				case 2: //Team colour
					Serial.printf("TeamCol %d\n", num);
					target_team = num;
					break;
			}
		} else {
			switch(c) {
				case 'w': print_wifi_details(); break;

				case 'a': 
					serial_mode = 1;
					Serial.println("Mode: animation");
					break;
				case 'b':
					serial_mode = 0;
					Serial.println("Mode: buzz");
					break;
				case 't':
					serial_mode = 2;
					Serial.println("Mode: team colour");
					break;

				case 'm': anim_set_anim(MEGAMAS, 0); break;
				case 'z': anim_buzz_team(target_team); break;

				case 'O': setLEDsNoAnim(RgbColor(0,0,0)); break;
				case 'R': setLEDsNoAnim(RgbColor(255,0,0)); break;
				case 'G': setLEDsNoAnim(RgbColor(0,255,0)); break;
				case 'B': setLEDsNoAnim(RgbColor(0,0,255)); break;
				
				case '=':
					singleled++;
					if (singleled >= NUM_LEDS) singleled = NUM_LEDS - 1;
					single_led(singleled);
					break;
				case '-':
					if(singleled > 0) singleled--;
					single_led(singleled);
					break;
				default:
					Serial.print('#');
					break;
			}
		}
	}

	if(!OFFLINE_MODE) {
		network_tick();
	}
}

