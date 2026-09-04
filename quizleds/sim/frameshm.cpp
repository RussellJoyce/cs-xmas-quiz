#include "frameshm.h"

#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#include <atomic>
#include <cstdio>
#include <cstring>

//The Swift reader hand-writes these offsets, so pin every one of them here.
static_assert(offsetof(FrameShm, magic)     ==    0, "FrameShm.magic moved");
static_assert(offsetof(FrameShm, version)   ==    4, "FrameShm.version moved");
static_assert(offsetof(FrameShm, seq)       ==    8, "FrameShm.seq moved");
static_assert(offsetof(FrameShm, count)     ==   12, "FrameShm.count moved");
static_assert(offsetof(FrameShm, heartbeat) ==   16, "FrameShm.heartbeat moved");
static_assert(offsetof(FrameShm, frames)    ==   24, "FrameShm.frames moved");
static_assert(offsetof(FrameShm, lookup)    ==   32, "FrameShm.lookup moved");
static_assert(offsetof(FrameShm, rgb)       ==  544, "FrameShm.rgb moved");
static_assert(sizeof(FrameShm)              == 2080, "FrameShm size changed");

namespace {

FrameShm* shm = 0;
int shm_fd = -1;

double now_seconds() {
	struct timespec ts;
	clock_gettime(CLOCK_REALTIME, &ts);
	return (double) ts.tv_sec + (double) ts.tv_nsec / 1e9;
}

} //namespace

bool frameshm_active() { return shm != 0; }

bool frameshm_open(const char* path, uint32_t count, const uint8_t* lookup, uint32_t lookup_len) {
	if(count > FRAMESHM_MAX) return false;

	//No O_TRUNC: recreating the file would give it a new inode, and any reader that had
	//already mapped the old one would sit on a frozen frame for the rest of its life.
	shm_fd = open(path, O_RDWR | O_CREAT, 0600);
	if(shm_fd < 0) {
		fprintf(stderr, "ledsim: cannot open frame file '%s'\n", path);
		return false;
	}
	if(ftruncate(shm_fd, sizeof(FrameShm)) != 0) {
		fprintf(stderr, "ledsim: cannot size frame file '%s'\n", path);
		close(shm_fd);
		shm_fd = -1;
		return false;
	}

	void* p = mmap(0, sizeof(FrameShm), PROT_READ | PROT_WRITE, MAP_SHARED, shm_fd, 0);
	if(p == MAP_FAILED) {
		fprintf(stderr, "ledsim: cannot map frame file '%s'\n", path);
		close(shm_fd);
		shm_fd = -1;
		return false;
	}
	shm = (FrameShm*) p;

	//A file left over from an older run may hold anything, so everything except magic is
	//initialised first and magic is stored last: a reader never sees a half-built region.
	shm->version = FRAMESHM_VERSION;
	shm->seq = 0;
	shm->count = count;
	shm->frames = 0;
	shm->heartbeat = now_seconds();
	memset(shm->lookup, 0, sizeof(shm->lookup));
	if(lookup && lookup_len) {
		memcpy(shm->lookup, lookup, lookup_len > FRAMESHM_MAX ? FRAMESHM_MAX : lookup_len);
	}
	memset(shm->rgb, 0, sizeof(shm->rgb));

	std::atomic_thread_fence(std::memory_order_release);
	shm->magic = FRAMESHM_MAGIC;
	return true;
}

void frameshm_write(const uint8_t* rgb, uint32_t count) {
	if(!shm) return;
	if(count > FRAMESHM_MAX) count = FRAMESHM_MAX;

	shm->seq++;                                            //Odd: write in progress
	std::atomic_thread_fence(std::memory_order_release);

	memcpy(shm->rgb, rgb, count * 3);
	shm->count = count;
	shm->frames++;

	std::atomic_thread_fence(std::memory_order_release);
	shm->seq++;                                            //Even: settled
}

void frameshm_heartbeat() {
	if(!shm) return;
	shm->heartbeat = now_seconds();
}

void frameshm_close() {
	if(shm) {
		munmap(shm, sizeof(FrameShm));
		shm = 0;
	}
	if(shm_fd >= 0) {
		close(shm_fd);
		shm_fd = -1;
	}
}
