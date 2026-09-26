/*
FreeRTOS queues on a mutex and condition variables. See freertos/queue.h.
*/

#include "freertos/queue.h"

#include <chrono>
#include <condition_variable>
#include <cstring>
#include <mutex>
#include <vector>

struct QueueDefinition {
	std::mutex lock;
	std::condition_variable not_empty;
	std::condition_variable not_full;
	std::vector<uint8_t> storage;   //length * item_size bytes, used as a ring
	UBaseType_t length;
	UBaseType_t item_size;
	UBaseType_t head;               //index of the oldest item
	UBaseType_t count;
};

namespace {

//Wait on cv until ready() holds or the timeout expires. Returns whether ready() holds.
template <typename Pred>
bool wait_for(std::condition_variable& cv, std::unique_lock<std::mutex>& held, TickType_t ticks, Pred ready) {
	if(ticks == portMAX_DELAY) {
		cv.wait(held, ready);
		return true;
	}
	return cv.wait_for(held, std::chrono::milliseconds(ticks * portTICK_PERIOD_MS), ready);
}

}

QueueHandle_t xQueueCreate(UBaseType_t length, UBaseType_t item_size) {
	if(length == 0 || item_size == 0) return NULL;
	QueueDefinition* q = new QueueDefinition();
	q->storage.resize((size_t) length * item_size);
	q->length = length;
	q->item_size = item_size;
	q->head = 0;
	q->count = 0;
	return q;
}

void vQueueDelete(QueueHandle_t queue) {
	delete queue;
}

BaseType_t xQueueSend(QueueHandle_t q, const void* item, TickType_t ticks_to_wait) {
	std::unique_lock<std::mutex> held(q->lock);
	if(!wait_for(q->not_full, held, ticks_to_wait, [q] { return q->count < q->length; })) {
		return errQUEUE_FULL;
	}
	UBaseType_t tail = (q->head + q->count) % q->length;
	memcpy(&q->storage[(size_t) tail * q->item_size], item, q->item_size);
	q->count++;
	q->not_empty.notify_one();
	return pdPASS;
}

BaseType_t xQueueReceive(QueueHandle_t q, void* buffer, TickType_t ticks_to_wait) {
	std::unique_lock<std::mutex> held(q->lock);
	if(!wait_for(q->not_empty, held, ticks_to_wait, [q] { return q->count > 0; })) {
		return errQUEUE_EMPTY;
	}
	memcpy(buffer, &q->storage[(size_t) q->head * q->item_size], q->item_size);
	q->head = (q->head + 1) % q->length;
	q->count--;
	q->not_full.notify_one();
	return pdPASS;
}

UBaseType_t uxQueueMessagesWaiting(QueueHandle_t q) {
	std::lock_guard<std::mutex> held(q->lock);
	return q->count;
}
