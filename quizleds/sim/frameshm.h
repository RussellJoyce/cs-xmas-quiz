#ifndef SIM_FRAMESHM_H
#define SIM_FRAMESHM_H

/*
Publishes the strip to a small shared-memory file so that other processes -- the Quiz
Server app in particular -- can display it.

This header is the authority on the layout. The Swift reader hand-writes the same
offsets, so every field below is pinned with a static_assert in frameshm.cpp: changing
the struct breaks the build rather than quietly desynchronising the reader.

A frame is published with a seqlock. The writer makes `seq` odd, stores the pixels, then
makes it even again; a reader that sees an odd value, or a different value either side of
its read, retries. Nothing here can ever block the animation loop: the writer always
stores into the same mapping, and a slow reader simply misses intermediate frames, which
is what a display should do anyway.
*/

#include <stdint.h>
#include <stddef.h>

#define FRAMESHM_MAGIC   0x4C454431u  /* "LED1" */
#define FRAMESHM_VERSION 1u
#define FRAMESHM_MAX     512          /* Largest strip the mapping can carry */

#define FRAMESHM_DEFAULT_PATH "/tmp/quizledsim.frame"

//Field offsets are fixed for the life of the format. See frameshm.cpp for the asserts.
struct FrameShm {
	uint32_t magic;                     /* 0    FRAMESHM_MAGIC once ledsim has claimed it */
	uint32_t version;                   /* 4  */
	uint32_t seq;                       /* 8    Odd while a frame is being written */
	uint32_t count;                     /* 12   LEDs actually in use */
	double   heartbeat;                 /* 16   CLOCK_REALTIME seconds, written from loop() */
	uint64_t frames;                    /* 24   Total Show() calls, for an fps readout */
	uint8_t  lookup[FRAMESHM_MAX];      /* 32   ledlookup, published once at startup */
	uint8_t  rgb[FRAMESHM_MAX * 3];     /* 544 */
};                                      /* 2080 bytes */

//Creates the file if it is not there and maps it. The file is never truncated or
//unlinked, so a reader that mapped it earlier keeps working across a restart of ledsim.
//Returns false and leaves publishing switched off if anything fails.
bool frameshm_open(const char* path, uint32_t count, const uint8_t* lookup, uint32_t lookup_len);

//count*3 bytes of RGB.
void frameshm_write(const uint8_t* rgb, uint32_t count);

//Liveness. Written unconditionally from the main loop, so that a reader can tell a
//simulator that is merely idle -- an animation that has settled stops calling Show() --
//from one that is not running at all.
void frameshm_heartbeat();

void frameshm_close();

bool frameshm_active();

#endif
