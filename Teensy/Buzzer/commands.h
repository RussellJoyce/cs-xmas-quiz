// Possible commands for serial control

#ifndef __COMMANDS_H
#define __COMMANDS_H

#define STATUS       0x00
#define RESET        0x01

#define LEDS_ANIM    0x10
#define LEDS_TEAM    0x20
#define LEDS_TEAMC   0x30
#define LEDS_COL     0x40
#define LEDS_TESTON  0x50
#define LEDS_TESTOFF 0x60
#define LEDS_POINTW  0x80
#define LEDS_POINTC  0x90

#define LED_ON       0xA0
#define LED_OFF      0xB0
#define LED_ALLON    0xC0
#define LED_ALLOFF   0xD0
#define POINT_STATE  0xE0

#endif