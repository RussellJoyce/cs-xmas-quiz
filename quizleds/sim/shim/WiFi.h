#ifndef SIM_WIFI_H
#define SIM_WIFI_H

/*
Host stand-in for the ESP32 WiFi class.

The simulator is already on a network, so this reports itself as permanently connected.
the first net_tick() after net_begin() finds it joined, and the check for a dropped
connection never fires, which is the behaviour of a healthy board.
*/

#include <Arduino.h>

#define WL_CONNECTED 3

typedef enum { WIFI_OFF = 0, WIFI_STA = 1 } wifi_mode_t;

class WiFiClass {
public:
	void setHostname(const char* name) { hostname = name; }
	void begin(const String& ssid, const String& pass) { (void) ssid; (void) pass; }
	int status() const { return WL_CONNECTED; }
	void disconnect() {}
	bool mode(wifi_mode_t m) { (void) m; return true; }
	String localIP() const { return String("127.0.0.1 (simulated)"); }
private:
	String hostname;
};

extern WiFiClass WiFi;

#endif
