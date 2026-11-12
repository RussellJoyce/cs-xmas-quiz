/*
Host stand-in for src/ota.cpp. A simulated tree cannot be reflashed; it reports what it
would have fetched and carries on as if it were up to date.
*/

#include <ota.h>
#include <Arduino.h>

ota_result ota_update(const char *host, int port, const char *name, ota_progress_cb progress) {
	Serial.printf("Update from http://%s:%d/firmware/%s.bin (not simulated)\n", host, port, name);
	if(progress) progress(1, 1);
	return OTA_UP_TO_DATE;
}
