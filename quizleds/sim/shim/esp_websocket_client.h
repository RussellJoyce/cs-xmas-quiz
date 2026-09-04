#ifndef SIM_ESP_WEBSOCKET_CLIENT_H
#define SIM_ESP_WEBSOCKET_CLIENT_H

/*
Host stand-in for the ESP-IDF websocket client.

Same API surface web.cpp uses, but backed by a real RFC6455 client over a POSIX socket,
so the simulator connects to the node server's LED port exactly as the board does and
the server cannot tell the difference.

As on the ESP32 the receive loop runs on its own thread, and events are delivered from
that thread rather than from the one running loop(). That is why web.cpp copies the
command out into command_to_parse and parses it later; the same race exists here.
*/

#include <stdint.h>
#include <stddef.h>

#define ESP_OK 0
#define ESP_FAIL -1
typedef int esp_err_t;
typedef const char* esp_event_base_t;

typedef enum {
	WEBSOCKET_EVENT_ANY = -1,
	WEBSOCKET_EVENT_ERROR = 0,
	WEBSOCKET_EVENT_CONNECTED,
	WEBSOCKET_EVENT_DISCONNECTED,
	WEBSOCKET_EVENT_DATA,
	WEBSOCKET_EVENT_CLOSED
} esp_websocket_event_id_t;

typedef struct {
	const char* uri;
} esp_websocket_client_config_t;

typedef struct {
	const char* data_ptr;
	int data_len;
	int payload_len;
	int payload_offset;
	uint8_t op_code;
} esp_websocket_event_data_t;

struct esp_websocket_client;
typedef struct esp_websocket_client* esp_websocket_client_handle_t;

typedef void (*esp_event_handler_t)(void* handler_args, esp_event_base_t base,
                                    int32_t event_id, void* event_data);

esp_websocket_client_handle_t esp_websocket_client_init(const esp_websocket_client_config_t* config);
esp_err_t esp_websocket_register_events(esp_websocket_client_handle_t client,
                                        esp_websocket_event_id_t event,
                                        esp_event_handler_t handler,
                                        void* handler_args);
esp_err_t esp_websocket_client_start(esp_websocket_client_handle_t client);
esp_err_t esp_websocket_client_stop(esp_websocket_client_handle_t client);
esp_err_t esp_websocket_client_destroy(esp_websocket_client_handle_t client);

//Simulator hooks, not part of the ESP-IDF API.
//Overrides the URI in the config passed to init, so the firmware's own credentials
//header can stay untouched while the simulator points at a local server.
void sim_websocket_set_uri(const char* uri);
//True once the handshake has completed, for the status line.
bool sim_websocket_is_connected();
//The last text frame received, for the status line.
const char* sim_websocket_last_message();

#endif
