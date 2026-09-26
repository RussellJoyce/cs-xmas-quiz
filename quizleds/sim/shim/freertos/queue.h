#ifndef SIM_FREERTOS_QUEUE_H
#define SIM_FREERTOS_QUEUE_H

/*
Host stand-in for FreeRTOS queues (freertos/queue.h).

A fixed-capacity FIFO of fixed-size items, copied in and out by value as the real thing
does, and safe to use from the websocket client's thread and loop() at once. Timeouts
behave as on the board: 0 returns immediately, portMAX_DELAY waits indefinitely, and
anything else waits that many milliseconds.
*/

#include "FreeRTOS.h"

struct QueueDefinition;
typedef struct QueueDefinition* QueueHandle_t;

QueueHandle_t xQueueCreate(UBaseType_t length, UBaseType_t item_size);
void vQueueDelete(QueueHandle_t queue);

BaseType_t xQueueSend(QueueHandle_t queue, const void* item, TickType_t ticks_to_wait);
BaseType_t xQueueReceive(QueueHandle_t queue, void* buffer, TickType_t ticks_to_wait);
UBaseType_t uxQueueMessagesWaiting(QueueHandle_t queue);

#define xQueueSendToBack xQueueSend

#endif
