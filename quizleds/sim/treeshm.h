#ifndef SIM_TREESHM_H
#define SIM_TREESHM_H

/*
The trees that treesim is running, published to a small shared-memory file so that other
processes -- the Quiz Server app in particular -- can display them. The counterpart of
frameshm.h for the string, and built the same way.

This header is the authority on the layout. The Swift reader hand-writes the same offsets,
so every field is pinned with a static_assert in treesim.cpp.

The file is the memory treesim's processes share: the parent maps it before forking, so each
child writes its own slot directly. Within a slot the child owns everything except `process`
and `id`, which the parent sets, and a ring is published with a seqlock as in frameshm.h:
`seq` is odd while the child is writing `rgb`.

Liveness is the header's `heartbeat`, written by the parent. A frozen or dead tree is still
reported, by its slot's `process`, so the reader can show it rather than drop it.

The file is created if absent and never truncated or unlinked, so treesim can be restarted
underneath a reader that has already mapped it.
*/

#include <stdint.h>
#include <stddef.h>

#define TREESHM_MAGIC   0x54524531u  /* "TRE1" */
#define TREESHM_VERSION 1u
#define TREESHM_MAX     32           /* Most trees the file can carry */
#define TREESHM_LEDS    8            /* LEDs per tree */

#define TREESHM_DEFAULT_PATH "/tmp/quiztreesim.frame"

//TreeShmSlot.process
#define TREESHM_DEAD    0u
#define TREESHM_RUNNING 1u
#define TREESHM_FROZEN  2u

struct TreeShmSlot {
	uint32_t seq;                       /* 0    Odd while rgb is being written */
	uint32_t process;                   /* 4    TREESHM_DEAD, _RUNNING or _FROZEN; parent */
	uint64_t frames;                    /* 8    Show() calls since the tree last started */
	int32_t  index;                     /* 16   From the last iNNCC, -1 before one arrives */
	int32_t  count;                     /* 20 */
	uint32_t connected;                 /* 24   Websocket handshake done */
	uint32_t reserved;                  /* 28 */
	char     id[8];                     /* 32   e.g. "510001", NUL terminated; parent */
	uint8_t  rgb[TREESHM_LEDS * 3];     /* 40   The bytes sent to the LEDs, LED 0 first */
	char     last[32];                  /* 64   Last text frame received, NUL terminated */
};                                      /* 96 bytes */

struct TreeShm {
	uint32_t magic;                     /* 0    TREESHM_MAGIC once treesim has claimed it */
	uint32_t version;                   /* 4  */
	uint32_t trees;                     /* 8    Slots in use */
	uint32_t leds;                      /* 12   TREESHM_LEDS */
	double   heartbeat;                 /* 16   CLOCK_REALTIME seconds, from the parent */
	uint8_t  reserved[8];               /* 24 */
	TreeShmSlot slot[TREESHM_MAX];      /* 32 */
};                                      /* 3104 bytes */

#endif
