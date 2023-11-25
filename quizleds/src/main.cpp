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

	connectWifi();
	anim_init();
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
	if(Serial.available()) {
		char c = Serial.read();
		switch(c) {
			case 'w':
				print_wifi_details();
				break;
			case 'm': anim_set_anim(MEGAMAS, 0);
			case 'o': setLEDsNoAnim(RgbColor(0,0,0)); break;
			case 'r': setLEDsNoAnim(RgbColor(255,0,0)); break;
			case 'g': setLEDsNoAnim(RgbColor(0,255,0)); break;
			case 'b': setLEDsNoAnim(RgbColor(0,0,255)); break;
			default:
				Serial.print('#');
				break;
		}
	}

	network_tick();
}
