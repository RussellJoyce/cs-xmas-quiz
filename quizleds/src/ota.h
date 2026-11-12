#ifndef OTA_H_
#define OTA_H_

// Firmware update over WiFi, pulled from the quiz server. The server serves each image over
// plain HTTP at http://<host>:<port>/firmware/<name>.bin; see nodeserver/firmware.js.
//
// The running image's MD5 goes with the request, and the server answers 304 if it already
// has that image, so asking a tree that is up to date costs one round trip. On success the
// board reboots into the new image and this does not return. On failure (no file, a broken
// download, a bad image) nothing is changed and the old image keeps running.

typedef void (*ota_progress_cb)(int done, int total);

typedef enum { OTA_FAILED, OTA_UP_TO_DATE } ota_result;

ota_result ota_update(const char *host, int port, const char *name, ota_progress_cb progress);

#endif
