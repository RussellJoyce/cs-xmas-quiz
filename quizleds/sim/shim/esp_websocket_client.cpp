/*
A minimal RFC6455 client behind the ESP-IDF websocket API. See esp_websocket_client.h.

Deliberately small: the LED protocol is a handful of short text frames in one direction,
over plain ws to a server on the same machine. There is no TLS, no compression and
nothing is ever sent upstream except the pong that keeps a server-side ping alive.
*/

#include "esp_websocket_client.h"

#include <arpa/inet.h>
#include <netdb.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <unistd.h>

#include <atomic>
#include <chrono>
#include <string>
#include <thread>
#include <vector>
#include <cstdio>
#include <cstring>
#include <cstdlib>

namespace {

const char* BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

std::string base64(const uint8_t* data, size_t len) {
	std::string out;
	for(size_t i = 0; i < len; i += 3) {
		uint32_t v = data[i] << 16;
		if(i + 1 < len) v |= data[i + 1] << 8;
		if(i + 2 < len) v |= data[i + 2];
		out += BASE64[(v >> 18) & 0x3f];
		out += BASE64[(v >> 12) & 0x3f];
		out += (i + 1 < len) ? BASE64[(v >> 6) & 0x3f] : '=';
		out += (i + 2 < len) ? BASE64[v & 0x3f] : '=';
	}
	return out;
}

std::string sim_uri_override;

//Last text frame received, purely so the simulator can show it on its status line.
char last_message[32] = {0};

void noteMessage(const char* p, size_t len) {
	if(len >= sizeof(last_message)) len = sizeof(last_message) - 1;
	memcpy(last_message, p, len);
	last_message[len] = 0;
}

} //namespace

struct esp_websocket_client {
	std::string host;
	std::string port;
	std::string path;

	esp_event_handler_t handler = 0;
	void* handler_args = 0;

	std::atomic<bool> running{false};
	std::atomic<bool> connected{false};
	std::thread worker;
	int fd = -1;

	void emit(esp_websocket_event_id_t id, esp_websocket_event_data_t* data) {
		if(handler) handler(handler_args, "WEBSOCKET_EVENTS", (int32_t) id, data);
	}
	void emit(esp_websocket_event_id_t id) {
		esp_websocket_event_data_t empty;
		memset(&empty, 0, sizeof(empty));
		emit(id, &empty);
	}

	bool parseUri(const std::string& uri);
	bool openSocket();
	bool handshake();
	void run();
	bool readExactly(uint8_t* buf, size_t len);
	void sendFrame(uint8_t opcode, const uint8_t* payload, size_t len);
};

//ws://host[:port][/path]. Anything else (notably wss://) is rejected rather than
//silently downgraded, so a misconfigured URI is obvious.
bool esp_websocket_client::parseUri(const std::string& uri) {
	const std::string scheme = "ws://";
	if(uri.compare(0, scheme.size(), scheme) != 0) return false;

	std::string rest = uri.substr(scheme.size());
	size_t slash = rest.find('/');
	std::string authority = (slash == std::string::npos) ? rest : rest.substr(0, slash);
	path = (slash == std::string::npos) ? "/" : rest.substr(slash);

	size_t colon = authority.rfind(':');
	if(colon == std::string::npos) {
		host = authority;
		port = "80";
	} else {
		host = authority.substr(0, colon);
		port = authority.substr(colon + 1);
	}
	return !host.empty() && !port.empty();
}

bool esp_websocket_client::openSocket() {
	struct addrinfo hints;
	memset(&hints, 0, sizeof(hints));
	hints.ai_family = AF_UNSPEC;
	hints.ai_socktype = SOCK_STREAM;

	struct addrinfo* res = 0;
	if(getaddrinfo(host.c_str(), port.c_str(), &hints, &res) != 0) return false;

	for(struct addrinfo* a = res; a; a = a->ai_next) {
		int s = socket(a->ai_family, a->ai_socktype, a->ai_protocol);
		if(s < 0) continue;
		if(connect(s, a->ai_addr, a->ai_addrlen) == 0) {
			int one = 1;
			setsockopt(s, IPPROTO_TCP, TCP_NODELAY, &one, sizeof(one));
			fd = s;
			break;
		}
		close(s);
	}
	freeaddrinfo(res);
	return fd >= 0;
}

bool esp_websocket_client::handshake() {
	uint8_t nonce[16];
	for(int i = 0; i < 16; i++) nonce[i] = (uint8_t) (rand() & 0xff);
	std::string key = base64(nonce, sizeof(nonce));

	char req[512];
	int n = snprintf(req, sizeof(req),
	                 "GET %s HTTP/1.1\r\n"
	                 "Host: %s:%s\r\n"
	                 "Upgrade: websocket\r\n"
	                 "Connection: Upgrade\r\n"
	                 "Sec-WebSocket-Key: %s\r\n"
	                 "Sec-WebSocket-Version: 13\r\n"
	                 "\r\n",
	                 path.c_str(), host.c_str(), port.c_str(), key.c_str());
	if(send(fd, req, n, 0) != n) return false;

	//Read headers a byte at a time so we do not consume any of the first frame.
	std::string headers;
	while(headers.size() < 4 || headers.compare(headers.size() - 4, 4, "\r\n\r\n") != 0) {
		char c;
		ssize_t got = recv(fd, &c, 1, 0);
		if(got != 1) return false;
		headers += c;
		if(headers.size() > 8192) return false;
	}
	//The server's Sec-WebSocket-Accept is not verified. Nothing here is hostile, and
	//checking it would mean pulling in SHA-1 for no practical gain.
	return headers.compare(0, 12, "HTTP/1.1 101") == 0;
}

bool esp_websocket_client::readExactly(uint8_t* buf, size_t len) {
	size_t got = 0;
	while(got < len) {
		ssize_t n = recv(fd, buf + got, len - got, 0);
		if(n <= 0) return false;
		got += (size_t) n;
	}
	return true;
}

//Client frames must be masked (RFC6455 5.3). Only ever used for pongs.
void esp_websocket_client::sendFrame(uint8_t opcode, const uint8_t* payload, size_t len) {
	if(len > 125) return;
	std::vector<uint8_t> frame;
	frame.push_back(0x80 | opcode);
	frame.push_back(0x80 | (uint8_t) len);
	uint8_t mask[4];
	for(int i = 0; i < 4; i++) { mask[i] = (uint8_t) (rand() & 0xff); frame.push_back(mask[i]); }
	for(size_t i = 0; i < len; i++) frame.push_back(payload[i] ^ mask[i % 4]);
	send(fd, frame.data(), frame.size(), 0);
}

void esp_websocket_client::run() {
	while(running) {
		if(!openSocket() || !handshake()) {
			if(fd >= 0) { close(fd); fd = -1; }
			//The real client retries on its own, which is why web.cpp's reconnect call
			//inside the disconnect event is commented out. Match that.
			for(int i = 0; i < 20 && running; i++) {
				std::this_thread::sleep_for(std::chrono::milliseconds(100));
			}
			continue;
		}

		connected = true;
		emit(WEBSOCKET_EVENT_CONNECTED);

		while(running) {
			uint8_t hdr[2];
			if(!readExactly(hdr, 2)) break;

			uint8_t opcode = hdr[0] & 0x0f;
			bool masked = (hdr[1] & 0x80) != 0;
			uint64_t len = hdr[1] & 0x7f;

			if(len == 126) {
				uint8_t ext[2];
				if(!readExactly(ext, 2)) break;
				len = ((uint64_t) ext[0] << 8) | ext[1];
			} else if(len == 127) {
				uint8_t ext[8];
				if(!readExactly(ext, 8)) break;
				len = 0;
				for(int i = 0; i < 8; i++) len = (len << 8) | ext[i];
			}
			if(len > (1 << 20)) break; //Nothing legitimate on this link is that big

			uint8_t mask[4] = {0, 0, 0, 0};
			if(masked && !readExactly(mask, 4)) break;

			std::vector<uint8_t> payload((size_t) len + 1, 0);
			if(len && !readExactly(payload.data(), (size_t) len)) break;
			if(masked) {
				for(uint64_t i = 0; i < len; i++) payload[i] ^= mask[i % 4];
			}

			if(opcode == 0x8) break;                                //close
			if(opcode == 0x9) sendFrame(0xA, payload.data(), (size_t) len); //ping -> pong
			if(opcode == 0x1) noteMessage((const char*) payload.data(), (size_t) len);

			esp_websocket_event_data_t data;
			memset(&data, 0, sizeof(data));
			data.data_ptr = (const char*) payload.data();
			data.data_len = (int) len;
			data.payload_len = (int) len;
			data.op_code = opcode;
			emit(WEBSOCKET_EVENT_DATA, &data);
		}

		connected = false;
		if(fd >= 0) { close(fd); fd = -1; }
		emit(WEBSOCKET_EVENT_DISCONNECTED);

		for(int i = 0; i < 10 && running; i++) {
			std::this_thread::sleep_for(std::chrono::milliseconds(100));
		}
	}
}

//-------------------------------------------------------------------------------------------------

void sim_websocket_set_uri(const char* uri) { sim_uri_override = uri ? uri : ""; }

static esp_websocket_client* the_client = 0;
bool sim_websocket_is_connected() { return the_client && the_client->connected; }
const char* sim_websocket_last_message() { return last_message; }

esp_websocket_client_handle_t esp_websocket_client_init(const esp_websocket_client_config_t* config) {
	esp_websocket_client* c = new esp_websocket_client();
	std::string uri = !sim_uri_override.empty() ? sim_uri_override
	                : (config && config->uri ? config->uri : "");
	if(!c->parseUri(uri)) {
		fprintf(stderr, "ledsim: cannot parse websocket uri '%s'\n", uri.c_str());
		delete c;
		return 0;
	}
	the_client = c;
	return c;
}

esp_err_t esp_websocket_register_events(esp_websocket_client_handle_t client,
                                        esp_websocket_event_id_t event,
                                        esp_event_handler_t handler,
                                        void* handler_args) {
	(void) event; //Only WEBSOCKET_EVENT_ANY is used, so there is nothing to filter on
	if(!client) return ESP_FAIL;
	client->handler = handler;
	client->handler_args = handler_args;
	return ESP_OK;
}

esp_err_t esp_websocket_client_start(esp_websocket_client_handle_t client) {
	if(!client || client->running) return ESP_FAIL;
	client->running = true;
	client->worker = std::thread([client] { client->run(); });
	return ESP_OK;
}

esp_err_t esp_websocket_client_stop(esp_websocket_client_handle_t client) {
	if(!client || !client->running) return ESP_FAIL;
	client->running = false;
	if(client->fd >= 0) shutdown(client->fd, SHUT_RDWR);
	if(client->worker.joinable()) client->worker.join();
	return ESP_OK;
}

esp_err_t esp_websocket_client_destroy(esp_websocket_client_handle_t client) {
	if(!client) return ESP_FAIL;
	esp_websocket_client_stop(client);
	if(the_client == client) the_client = 0;
	delete client;
	return ESP_OK;
}
