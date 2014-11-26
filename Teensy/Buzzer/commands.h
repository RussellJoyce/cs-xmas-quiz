// Possible commands for serial control

#ifndef __COMMANDS_H
#define __COMMANDS_H

#define STATUS       0x00
#define RESET        0x01

#define LEDS_OFF     0x10
#define LEDS_TWINKLE 0x11

#define LEDS_TEAM    0x20
#define LEDS_TEAM1   0x21
#define LEDS_TEAM2   0x22
#define LEDS_TEAM3   0x23
#define LEDS_TEAM4   0x24
#define LEDS_TEAM5   0x25
#define LEDS_TEAM6   0x26
#define LEDS_TEAM7   0x27
#define LEDS_TEAM8   0x28

#define LEDS_TEAMR   0x30
#define LEDS_TEAM1R  0x31
#define LEDS_TEAM2R  0x32
#define LEDS_TEAM3R  0x33
#define LEDS_TEAM4R  0x34
#define LEDS_TEAM5R  0x35
#define LEDS_TEAM6R  0x36
#define LEDS_TEAM7R  0x37
#define LEDS_TEAM8R  0x38

#define LEDS_TEAMG   0x40
#define LEDS_TEAM1G  0x41
#define LEDS_TEAM2G  0x42
#define LEDS_TEAM3G  0x43
#define LEDS_TEAM4G  0x44
#define LEDS_TEAM5G  0x45
#define LEDS_TEAM6G  0x46
#define LEDS_TEAM7G  0x47
#define LEDS_TEAM8G  0x48

#define LED_ON       0xA0
#define LED_OFF      0xB0
#define LED_SET      0xC0

#endif