#ifndef SIM_NEOPIXELBUS_H
#define SIM_NEOPIXELBUS_H

/*
Host stand-in for NeoPixelBus.

The colour classes are the library's own sources, compiled unchanged, so RgbColor,
HsbColor and HslColor convert exactly as they do on the board. That matters: several
animations round-trip a colour through the strip (Counter::tick and BuzzRainbow::tick
both do HsbColor c = leds.GetPixelColor(i)), which quantises float HSB down to 8-bit
RGB and back. Reimplementing that maths would change what those animations look like.

Only the bus itself is faked. It keeps the pixel buffer that the real driver would DMA
out over RMT/I2S, and Show() hands it to the simulator front end instead.
*/

#include <Arduino.h>
#include <string.h>

#include <internal/NeoSettings.h>
#include <internal/colors/NeoHueBlend.h>
#include <internal/colors/RgbColorIndexes.h>
#include <internal/colors/RgbColorBase.h>
#include <internal/colors/RgbColor.h>
#include <internal/colors/Rgb16Color.h>
#include <internal/colors/Rgb48Color.h>
#include <internal/colors/HslColor.h>
#include <internal/colors/HsbColor.h>
#include <internal/colors/HtmlColor.h>
#include <internal/colors/RgbwColor.h>

//The colour ordering feature and the output method carry no behaviour we can simulate:
//NeoRgbFeature only fixes the byte order on the wire, and NeoWs2811Method is the DMA
//driver. Both are empty here; only the ColorObject typedef is actually used.
class NeoRgbFeature { public: typedef RgbColor ColorObject; };
class NeoWs2811Method {};

//Implemented by the simulator front end (simmain.cpp). Called from Show().
void sim_leds_show(const RgbColor* pixels, uint16_t count);

template<typename T_COLOR_FEATURE, typename T_METHOD> class NeoPixelBus {
public:
	typedef typename T_COLOR_FEATURE::ColorObject ColorObject;

	NeoPixelBus(uint16_t countPixels, uint8_t pin) : count(countPixels) {
		(void) pin;
		pixels = new ColorObject[count];
	}
	~NeoPixelBus() { delete[] pixels; }

	void Begin() {}

	//Out of range writes are dropped, as they are in the real library.
	void SetPixelColor(uint16_t indexPixel, ColorObject color) {
		if(indexPixel < count) pixels[indexPixel] = color;
	}

	ColorObject GetPixelColor(uint16_t indexPixel) const {
		return indexPixel < count ? pixels[indexPixel] : ColorObject(0);
	}

	void ClearTo(ColorObject color) {
		for(uint16_t i = 0; i < count; i++) pixels[i] = color;
	}

	void Show() { sim_leds_show(pixels, count); }

	uint16_t PixelCount() const { return count; }

private:
	NeoPixelBus(const NeoPixelBus&);
	NeoPixelBus& operator=(const NeoPixelBus&);

	uint16_t count;
	ColorObject* pixels;
};

#endif
