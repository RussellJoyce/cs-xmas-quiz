// Possible commands for serial control

#ifndef __COMMANDS_H
#define __COMMANDS_H

#define STATUS       0x00
#define RESET        0x01

#define LEDS_ANIM    0x10
#define LEDS_TEAM    0x20
#define LEDS_TEAMR   0x30
#define LEDS_TEAMG   0x40

#define LED_ON       0xA0
#define LED_OFF      0xB0
#define LED_SET      0xC0

#endif