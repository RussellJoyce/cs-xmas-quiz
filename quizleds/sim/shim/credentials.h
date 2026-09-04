#ifndef SIM_CREDENTIALS_H
#define SIM_CREDENTIALS_H

/*
Fallback credentials for the simulator.

src/credentials.h is not in the repository. web.cpp includes "credentials.h" with quotes,
so the real file next to it wins whenever it exists and this is only reached on a checkout
that has never built the firmware. The simulator overrides the websocket URI anyway
(--uri, default ws://127.0.0.1:8092/), so these values are never used to reach anything.
*/

#define NUM_CREDS 1

static const char* wifi_ssids[NUM_CREDS] = {"simulated"};
static const char* wifi_passes[NUM_CREDS] = {""};
static const char* websocket_uris[NUM_CREDS] = {"ws://127.0.0.1:8092/"};

#endif
