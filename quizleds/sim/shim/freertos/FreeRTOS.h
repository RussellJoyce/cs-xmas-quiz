#ifndef SIM_FREERTOS_H
#define SIM_FREERTOS_H

/*
Host stand-in for the FreeRTOS base header, as ESP-IDF lays it out (freertos/FreeRTOS.h).

Only the types and constants that the queue shim needs. Ticks are milliseconds, matching
the 1 kHz tick the ESP32 Arduino core is built with.
*/

#include <stdint.h>

typedef int BaseType_t;
typedef unsigned int UBaseType_t;
typedef uint32_t TickType_t;

#define pdFALSE ((BaseType_t) 0)
#define pdTRUE  ((BaseType_t) 1)
#define pdPASS  pdTRUE
#define pdFAIL  pdFALSE
#define errQUEUE_FULL  pdFAIL
#define errQUEUE_EMPTY pdFAIL

#define portMAX_DELAY     ((TickType_t) 0xffffffffUL)
#define portTICK_PERIOD_MS ((TickType_t) 1)
#define pdMS_TO_TICKS(ms) ((TickType_t) (ms))

#endif
