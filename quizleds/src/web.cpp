#include <web.h>
#include <settings.h>
#include <Arduino.h>
#include <WiFi.h>
#include "credentials.h"
#include "esp_websocket_client.h"
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <animation.h>


//Protocol:
//All numbers are fixed-width decimal. Team ids tt are 0-based.
// Set animation
//   a00 - off
//   a01 - megamas
//   a02 - timer twinkle
//   a03 - swell
//   a04 - embers
//   a05 - old christmas lights
//   Any other id is logged and ignored.
// Buzz for a team
//   btt - play the next buzzer animation in the rotation, ending on team tt's colour
// Set colour
//   crrrgggbbb - set the string to the specified rgb colour, components are ints 0-255
// Set team colour
//   ttt - set the string to the colour of team tt
// Set animation target to a team
//   ett - set the fade target of every LED to team tt's hue, which animations that fade
//         towards their target (megamas) then pick up
// Colour pulse
//   p00 - pulse string white
//   p01 - pulse string red
//   p02 - pulse string green
//   Any other value pulses white.
// Team pulse
//   qtt - slow pulse of team tt's colour
//   qTT - where TT >= 50, quick pulse of team TT-50's colour
// Music levels
//   mlllLLLrrrRRR - left average, left peak, right average, right peak, in LEDs (0-100).
//                   The right channel fills from the left end of the line, and the left
//                   channel from the right end.
// Counter
//   rxxx - light xxx LEDs (0 to NUM_LEDS) white from the left; the rest fade out from
//          random colours


#define WIFI_SSID(n) WIFI_SSID_##n
#define WIFI_PASS(n) WIFI_PASS_##n
#define WEBSOCKET_URI(n) WEBSOCKET_URI_##n

void connect_websocket();

//Commands arrive on the websocket client's task and are parsed later from loop()
#define COMMAND_MAX_LEN 64
#define COMMAND_QUEUE_LEN 32

typedef struct {
	char data[COMMAND_MAX_LEN];
	int length;
} Command;

static QueueHandle_t command_queue = NULL;

esp_websocket_client_config_t websocket_cfg = {
	.uri = websocket_uris[0]
};
esp_websocket_client_handle_t websocket_client;


void print_wifi_details() {
	Serial.println(WiFi.localIP());
}

void connectWifi() {
	if(command_queue == NULL) {
		command_queue = xQueueCreate(COMMAND_QUEUE_LEN, sizeof(Command));
	}

	WiFi.setHostname(HOSTNAME);
	Serial.println("Begin wifi...");

	int i = 0;
	while(1) {
		String wifi_ssid = wifi_ssids[i];
		String wifi_pass = wifi_passes[i];

		Serial.printf("Attempting SSID: %s\n", wifi_ssid.c_str());
		WiFi.begin(wifi_ssid, wifi_pass);
		unsigned long start = millis();

		while (WiFi.status() != WL_CONNECTED && millis() - start < 8000) {
            delay(200);
			Serial.print(".");
        }

		if (WiFi.status() == WL_CONNECTED) {
			print_wifi_details();
			websocket_cfg.uri = websocket_uris[i];
			Serial.println("Wifi started");
			break;
		}

		i++; 
		if(i >= NUM_CREDS) i = 0;
	}

	connect_websocket();
}

static void websocket_event_handler(void *handler_args, esp_event_base_t base, int32_t event_id, void *event_data)
{
    esp_websocket_event_data_t *data = (esp_websocket_event_data_t *)event_data;
    switch (event_id) {
    case WEBSOCKET_EVENT_CONNECTED:
        Serial.println("Websocket connected.");
        break;
    case WEBSOCKET_EVENT_DISCONNECTED:
        Serial.println("Websocket disconnected!");
		//connect_websocket();
        break;
    case WEBSOCKET_EVENT_DATA:
		switch(data->op_code) {
			case 1:
				if(data->data_len >= 3) { //All commands are at least 3 bytes
					Command cmd;
					cmd.length = data->data_len;
					if(cmd.length > COMMAND_MAX_LEN) cmd.length = COMMAND_MAX_LEN;
					memcpy(cmd.data, data->data_ptr, cmd.length);
					if(xQueueSend(command_queue, &cmd, 0) != pdTRUE) {
						Serial.printf("Command queue full, dropped %.*s\n", cmd.length, cmd.data);
					}
				}
				break;
			case 10:
				//keep alive ping. ignore.
				break;
			default:
				Serial.println("WEBSOCKET_EVENT_DATA");
				Serial.printf("Received opcode=%d\n", data->op_code);
				Serial.printf("Received=%.*s\n", data->data_len, (char *)data->data_ptr);
				Serial.printf("Total payload length=%d, data_len=%d\r\n", data->payload_len, data->data_len);
				break;
		}
		break;
    case WEBSOCKET_EVENT_ERROR:
        Serial.println("WEBSOCKET_EVENT_ERROR");
        break;
    }
}


void connect_websocket() {
	websocket_client = esp_websocket_client_init(&websocket_cfg);
	esp_websocket_register_events(websocket_client, WEBSOCKET_EVENT_ANY, websocket_event_handler, (void *)websocket_client);
	if(esp_websocket_client_start(websocket_client) != ESP_OK) {
		Serial.println("Error connecting to websocket");
	}
}

uint8_t bytesToInt(char *b) {
	return 100*(b[0]-'0') + 10*(b[1]-'0') + (b[2]-'0');
}

uint8_t bytesToInt2(char *b) {
	return 10*(b[0]-'0') + (b[1]-'0');
}


void network_tick() {
	//Check if we need to reconnect
	if(WiFi.status() != WL_CONNECTED) {
		WiFi.disconnect();
		connectWifi();
	}

	//Handle every command that has arrived since the last tick
	Command cmd;
	while(command_queue != NULL && xQueueReceive(command_queue, &cmd, 0) == pdTRUE) {
		char *dat = cmd.data;
		int command_length = cmd.length;
		switch(dat[0]) {
			case 'a': { //Set to a canned animation
				uint8_t animnum = bytesToInt2(&dat[1]);
				switch(animnum) {
					case 0:
						Serial.println("Anim: None");
						anim_set_anim(NONE, 0);
						break;
					case 1:
						Serial.println("Anim: Megamas");
						anim_set_anim(MEGAMAS, 0);
						break;
					case 2:
						Serial.println("Anim: Timer twinkle");
						anim_set_anim(TIMERTWINKLE, 0);
						break;
					case 3:
						Serial.println("Anim: Swell");
						anim_set_anim(SWELL, 0);
						break;
					case 4:
						Serial.println("Anim: Embers");
						anim_set_anim(EMBERS, 0);
						break;
					case 5:
						Serial.println("Anim: Old lights");
						anim_set_anim(OLDLIGHTS, 0);
						break;
					default:
						Serial.printf("Unknown animation %d\n", animnum);
						break;
				}
				break;
			}
			case 'b': { //A team is buzzing
				uint8_t teamid = bytesToInt2(&dat[1]);
				Serial.printf("Buzz %d\n", teamid);
				anim_buzz_team(teamid);
				break;
			}
			case 'c': { //Set the string to a specific colour
				if(command_length >= 10) {
					uint8_t r = bytesToInt(&dat[1]);
					uint8_t g = bytesToInt(&dat[4]);
					uint8_t b = bytesToInt(&dat[7]);
					setLEDsNoAnim(RgbColor(r, g, b));
				}
				break;
			}
			case 'e': { //Set the fade target of the string to a specific team's colour
				uint8_t teamid = bytesToInt2(&dat[1]);
				setTargetToTeam(teamid);
				break;
			}
			case 't': { //Set the string to a specific team's colour without animation
				uint8_t teamid = bytesToInt2(&dat[1]);
				Serial.printf("TeamCol %d\n", teamid);
				setLEDsNoAnim(team_col(teamid));
				break;
			}
			case 'p': { //Pulse the string a specific colour
				uint8_t param = bytesToInt2(&dat[1]);
				Serial.printf("Pulse col %d\n", param);
				anim_set_anim(COLOURPULSE, param);
				break;
			}
			case 'q': { //Pulse a specific team's colour
				uint8_t param = bytesToInt2(&dat[1]);
				Serial.printf("Pulse team %d\n", param);
				anim_set_anim(TEAMPULSE, param);
				break;
			}
			case 'm': { //Set music levels for the left and right channels
				if(command_length >= 13) {
					uint8_t la = bytesToInt(&dat[1]);
					uint8_t lp = bytesToInt(&dat[4]);
					uint8_t ra = bytesToInt(&dat[7]);
					uint8_t rp = bytesToInt(&dat[10]);
					set_music_levels(la, lp, ra, rp);
				}
				break;
			}
			case 'r': { //Set the string to a counter of LEDs lit
				if(command_length >= 4) {
					int c = (int) bytesToInt(&dat[1]);
					anim_set_anim(COUNTER, c);
				}
				break;
			} 
			default:
				Serial.printf("LED Command %c\n", dat[0]);
				break;
		}
	}

}

