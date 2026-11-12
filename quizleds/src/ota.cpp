#include <ota.h>
#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <Update.h>

// The download is written to flash here rather than by the core's HTTPUpdate. HTTPUpdate
// hands the stream to Update.writeStream(), which retries an empty read 300 times, each after
// the client's full timeout (8 s by default): if the server goes away mid-download, the tree
// sits frozen for about 40 minutes before giving up. This loop gives up as soon as the
// connection closes early, or after OTA_IDLE_TIMEOUT_MS with no data (a WiFi drop that never
// closes it).
#define OTA_IDLE_TIMEOUT_MS 10000
#define OTA_CHUNK 1024

static ota_result fail(HTTPClient &http, bool started, const char *why) {
	if(started) Update.abort();
	http.end();
	Serial.printf("Update failed: %s\n", why);
	return OTA_FAILED;
}

ota_result ota_update(const char *host, int port, const char *name, ota_progress_cb progress) {
	char url[128], why[96];
	snprintf(url, sizeof(url), "http://%s:%d/firmware/%s.bin", host, port, name);
	Serial.printf("Update from %s\n", url);

	WiFiClient client;
	HTTPClient http;
	http.setTimeout(OTA_IDLE_TIMEOUT_MS);
	if(!http.begin(client, url)) return fail(http, false, "bad URL");

	// The server compares this with its file, and answers 304 if they are the same
	http.addHeader("x-ESP32-sketch-md5", ESP.getSketchMD5());
	// Only for the server's log, which names the tree by it
	http.addHeader("x-ESP32-STA-MAC", WiFi.macAddress());
	const char *keep[] = { "x-MD5" };
	http.collectHeaders(keep, 1);

	int code = http.GET();
	if(code == HTTP_CODE_NOT_MODIFIED) {
		http.end();
		Serial.println("Already up to date");
		return OTA_UP_TO_DATE;
	}
	if(code != HTTP_CODE_OK) {
		snprintf(why, sizeof(why), "HTTP %d %s", code, code < 0 ? http.errorToString(code).c_str() : "");
		return fail(http, false, why);
	}

	int total = http.getSize();
	if(total <= 0) return fail(http, false, "no Content-Length");
	if(!Update.begin(total, U_FLASH)) return fail(http, false, Update.errorString());

	// Checked by Update.end(): a damaged download is never booted
	String md5 = http.header("x-MD5");
	if(md5.length() == 32) Update.setMD5(md5.c_str());

	auto *stream = http.getStreamPtr();
	static uint8_t buf[OTA_CHUNK];
	int done = 0;
	uint32_t last_data = millis();
	if(progress) progress(0, total);
	while(done < total) {
		int avail = stream->available();
		if(avail > 0) {
			int n = stream->read(buf, avail < OTA_CHUNK ? avail : OTA_CHUNK);
			if(n <= 0) continue;
			if(Update.write(buf, n) != (size_t)n) return fail(http, true, Update.errorString());
			done += n;
			last_data = millis();
			if(progress) progress(done, total);
		} else if(!stream->connected()) {
			snprintf(why, sizeof(why), "connection closed after %d of %d bytes", done, total);
			return fail(http, true, why);
		} else if(millis() - last_data > OTA_IDLE_TIMEOUT_MS) {
			snprintf(why, sizeof(why), "no data for %d s, after %d of %d bytes",
			         OTA_IDLE_TIMEOUT_MS / 1000, done, total);
			return fail(http, true, why);
		} else {
			delay(1);
		}
	}

	// Checks the MD5 and marks the new image to boot next
	if(!Update.end()) return fail(http, false, Update.errorString());
	http.end();
	Serial.println("Update done, restarting");
	delay(100);
	ESP.restart();
	return OTA_FAILED;   // not reached
}
