#include <web.h>
#include <settings.h>
#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include "credentials.h"
#include "esp_websocket_client.h"
#include <animation.h>

#define WIFI_SSID(n) WIFI_SSID_##n
#define WIFI_PASS(n) WIFI_PASS_##n
#define WEBSOCKET_URI(n) WEBSOCKET_URI_##n

void connect_websocket();

char command_to_parse[20] = {0};
int command_length = 0;

esp_websocket_client_config_t websocket_cfg = {
	.uri = websocket_uris[0]
};
esp_websocket_client_handle_t websocket_client;


void print_wifi_details() {
	Serial.println(WiFi.localIP());
}

void connectWifi() {
	WiFi.setHostname(HOSTNAME);
	Serial.println("Begin wifi...");

	for (int i = 0; i < NUM_CREDS; i++) {	

		String wifi_ssid = wifi_ssids[i];
		String wifi_pass = wifi_passes[i];

		Serial.printf("Attempting SSID: %s\n", wifi_ssid);
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
		//We do a quick sanity check, then copy the command out so that it can be parsed outside of the context of an interrupt
		switch(data->op_code) {
			case 1:
				if(data->data_len >= 3) { //All commands are at least 3 bytes
					memcpy(command_to_parse, data->data_ptr, data->data_len);
				}
				command_length = data->data_len;
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

	//Protocol:
	// Set animation
	//   a00 - set animation id 0 (off)
	//   a01 - set animation id 1 (megamas)
	//   axx - etc.
	// Buzz for a team
	//   btt - trigger a random buzzer for team id tt
	// Set colour
	//   crrrgggbbb - set the string to the specified rgb colour, components are ints 0-255
	// Set team colour
	//   ttt - set the string to the colour of team tt (0-based)
	// Colour pulse
	//   p00 - pulse string white
	//   p01 - pulse string red
	//   p02 - pulse string green
	// Team pulse
	//   qtt - pulse string team colour
	// Music levels
	//   mlllLLLrrrRRR
	// Counter
	//   rxxx - Set the strings to the desired timer number (xxx = 0 to NUMLEDS)

	//Check for a command to handle
	if(command_to_parse[0] != 0) {
		char *dat = (char *) command_to_parse;
		switch(dat[0]) {
			case 'a': {
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
					default:
						Serial.printf("Unknown animation %d\n", animnum);
						break;
				}
				break;
			}
			case 'b': {
				uint8_t teamid = bytesToInt2(&dat[1]);
				Serial.printf("Buzz %d\n", teamid);
				anim_buzz_team(teamid);
				break;
			}
			case 'c': {
				if(command_length >= 10) {
					uint8_t r = bytesToInt(&command_to_parse[1]);
					uint8_t g = bytesToInt(&command_to_parse[4]);
					uint8_t b = bytesToInt(&command_to_parse[7]);
					setLEDsNoAnim(RgbColor(r, g, b));
				}
				break;
			}
			case 'e': {
				uint8_t teamid = bytesToInt2(&dat[1]);
				setTargetToTeam(teamid);
				break;
			}
			case 't': {
				uint8_t teamid = bytesToInt2(&dat[1]);
				Serial.printf("TeamCol %d\n", teamid);
				setLEDsNoAnim(team_col(teamid));
				break;
			}
			case 'p': {
				uint8_t param = bytesToInt2(&dat[1]);
				Serial.printf("Pulse col %d\n", param);
				anim_set_anim(COLOURPULSE, param);
				break;
			}
			case 'q': {
				uint8_t param = bytesToInt2(&dat[1]);
				Serial.printf("Pulse team %d\n", param);
				anim_set_anim(TEAMPULSE, param);
				break;
			}
			case 'm': {
				if(command_length >= 13) {
					uint8_t la = bytesToInt(&command_to_parse[1]);
					uint8_t lp = bytesToInt(&command_to_parse[4]);
					uint8_t ra = bytesToInt(&command_to_parse[7]);
					uint8_t rp = bytesToInt(&command_to_parse[10]);
					set_music_levels(la, lp, ra, rp);
				}
				break;
			}
			case 'r': {
				if(command_length >= 4) {
					int c = (int) bytesToInt(&command_to_parse[1]);
					anim_set_anim(COUNTER, c);
				}
				break;
			} 
			default:
				Serial.printf("LED Command %c\n", dat[0]);
				break;
		}

		command_to_parse[0] = 0;
		command_length = 0;
	}

}

