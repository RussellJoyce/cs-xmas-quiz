#include <net.h>
#include <Arduino.h>
#include <WiFi.h>
#include "credentials.h"
#include "esp_websocket_client.h"
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>

//Commands arrive on the websocket client's task and are parsed later from loop()
#define COMMAND_MAX_LEN 64
#define COMMAND_QUEUE_LEN 32
#define URI_MAX_LEN 160

typedef struct {
	char data[COMMAND_MAX_LEN];
	int length;
} Command;

static QueueHandle_t command_queue = NULL;

static const char *net_hostname = "quizleds";
static const char *net_query = NULL;
static char uri_buf[URI_MAX_LEN];

static esp_websocket_client_config_t websocket_cfg = {
	.uri = uri_buf
};
static esp_websocket_client_handle_t websocket_client = NULL;

static void connect_websocket();

//The URI from credentials.h with net_query added: "ws://host:8092/" becomes
//"ws://host:8092/?tree=d62534". A URI with no path gets one, as "ws://host:8092?x" is not valid.
static void build_uri(const char *base) {
	if(net_query == NULL || net_query[0] == 0) {
		snprintf(uri_buf, sizeof(uri_buf), "%s", base);
		return;
	}
	const char *scheme_end = strstr(base, "://");
	const char *after_host = scheme_end ? scheme_end + 3 : base;
	bool has_path = strchr(after_host, '/') != NULL;
	bool has_query = strchr(after_host, '?') != NULL;
	snprintf(uri_buf, sizeof(uri_buf), "%s%s%s", base,
	         has_query ? "&" : (has_path ? "?" : "/?"), net_query);
}

bool net_server_host(char *buf, int len) {
	const char *scheme_end = strstr(uri_buf, "://");
	if(scheme_end == NULL) return false;
	const char *host = scheme_end + 3;
	int n = strcspn(host, ":/?");
	if(n == 0 || n >= len) return false;
	memcpy(buf, host, n);
	buf[n] = 0;
	return true;
}

void net_print_details() {
	Serial.println(WiFi.localIP());
	Serial.println(uri_buf);
}

//Joining is a state machine stepped by net_tick(), so loop() and the animation never wait
//for WiFi. Each network in credentials.h gets JOIN_TIMEOUT_MS to answer before the next.
#define JOIN_TIMEOUT_MS 8000

typedef enum { NET_OFF, NET_JOINING, NET_CONNECTED } net_state;

static net_state state = NET_OFF;
static int cred = 0;                //The network being tried, or joined
static unsigned long join_start = 0;
static bool joined = false;

static void start_join(int i) {
	cred = i;
	Serial.printf("Attempting SSID: %s\n", wifi_ssids[cred]);
	WiFi.begin(wifi_ssids[cred], wifi_passes[cred]);
#ifdef NET_TX_POWER
	//The C3 SuperMini's antenna is poor, and it is widely reported to connect more
	//reliably at reduced transmit power
	WiFi.setTxPower(NET_TX_POWER);
#endif
	join_start = millis();
	state = NET_JOINING;
}

static void step_join() {
	if(WiFi.status() == WL_CONNECTED) {
		build_uri(websocket_uris[cred]);
		net_print_details();
		Serial.println("Wifi started");
		state = NET_CONNECTED;
		joined = true;
		connect_websocket();
		return;
	}
	if(millis() - join_start < JOIN_TIMEOUT_MS) return;

	//Abandon this attempt before the next. Core 3 (the trees) refuses WiFi.begin() while the
	//station is still trying to connect.
	WiFi.disconnect();
	start_join((cred + 1) % NUM_CREDS);
}

void net_begin(const char *hostname, const char *query) {
	if(command_queue == NULL) {
		command_queue = xQueueCreate(COMMAND_QUEUE_LEN, sizeof(Command));
	}
	net_hostname = hostname;
	net_query = query;
	WiFi.setHostname(net_hostname);
	Serial.println("Begin wifi...");
	start_join(0);
}

void net_end() {
	if(websocket_client != NULL) {
		esp_websocket_client_destroy(websocket_client);
		websocket_client = NULL;
	}
	if(state != NET_OFF) {
		WiFi.disconnect();
		WiFi.mode(WIFI_OFF);
		Serial.println("Wifi stopped");
	}
	state = NET_OFF;
}

bool net_running() {
	return state != NET_OFF;
}

bool net_has_joined() {
	return joined;
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

static void connect_websocket() {
	//After a WiFi drop the old client still exists, and its task keeps reconnecting by itself.
	//Left alone, it and the new client would both connect, and every command would arrive
	//twice. Destroying it stops its task first. A new client is still needed: the network
	//joined this time may have a different URI.
	if(websocket_client != NULL) {
		esp_websocket_client_destroy(websocket_client);
		websocket_client = NULL;
	}
	websocket_client = esp_websocket_client_init(&websocket_cfg);
	esp_websocket_register_events(websocket_client, WEBSOCKET_EVENT_ANY, websocket_event_handler, (void *)websocket_client);
	if(esp_websocket_client_start(websocket_client) != ESP_OK) {
		Serial.println("Error connecting to websocket");
	}
}

void net_tick(net_command_handler handler) {
	switch(state) {
		case NET_OFF:
			break;
		case NET_JOINING:
			step_join();
			break;
		case NET_CONNECTED:
			//Dropped: start again from the first network, as at boot
			if(WiFi.status() != WL_CONNECTED) {
				Serial.println("Wifi lost");
				WiFi.disconnect();
				start_join(0);
			}
			break;
	}

	//Handle every command that has arrived since the last tick
	Command cmd;
	while(command_queue != NULL && xQueueReceive(command_queue, &cmd, 0) == pdTRUE) {
		handler(cmd.data, cmd.length);
	}
}
