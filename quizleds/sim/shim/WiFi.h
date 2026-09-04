#ifndef SIM_WIFI_H
#define SIM_WIFI_H

/*
Host stand-in for the ESP32 WiFi class.

The simulator is already on a network, so this reports itself as permanently connected.
connectWifi() therefore succeeds on its first attempt and network_tick()'s reconnect
check never fires, which is the behaviour of a healthy board.
*/

#include <Arduino.h>

#define WL_CONNECTED 3

class WiFiClass {
public:
	void setHostname(const char* name) { hostname = name; }
	void begin(const String& ssid, const String& pass) { (void) ssid; (void) pass; }
	int status() const { return WL_CONNECTED; }
	void disconnect() {}
	String localIP() const { return String("127.0.0.1 (simulated)"); }
private:
	String hostname;
};

extern WiFiClass WiFi;

#endif
