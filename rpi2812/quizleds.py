# CS Christmas Quiz 2016 - RaspberryPi websocket led controller.


# NeoPixel library strandtest example
# Author: Tony DiCola (tony@tonydicola.com)
#
# Direct port of the Arduino NeoPixel library strandtest example.  Showcases
# various animations on a strip of NeoPixels.
import time, sys

from neopixel import *
import websocket
import thread
import json
import random
import colorsys

# LED strip configuration:
LED_COUNT      = 550      # Number of LED pixels.
LED_PIN        = 18      # GPIO pin connected to the pixels (must support PWM!).
LED_FREQ_HZ    = 800000  # LED signal frequency in hertz (usually 800khz)
LED_DMA        = 5       # DMA channel to use for generating signal (try 5)
LED_BRIGHTNESS = 255     # Set to 0 for darkest and 255 for brightest
LED_INVERT     = False   # True to invert the signal (when using NPN transistor level shift)


# Define functions which animate LEDs in various ways.

def theaterChase(strip, color, wait_ms=50, iterations=10):
    """Movie theater light style chaser animation."""
    for j in xrange(iterations):
        for q in xrange(3):
            for i in xrange(0, strip.numPixels(), 3):
                strip.setPixelColor(i+q, color)
            strip.show()
            time.sleep(wait_ms/1000.0)
            for i in xrange(0, strip.numPixels(), 3):
                strip.setPixelColor(i+q, 0)

def wheel(pos):
    """Generate rainbow colors across 0-255 positions."""
    if pos < 85:
        return Color(pos * 3, 255 - pos * 3, 0)
    elif pos < 170:
        pos -= 85
        return Color(255 - pos * 3, 0, pos * 3)
    else:
        pos -= 170
        return Color(0, pos * 3, 255 - pos * 3)

def rainbow(strip, wait_ms=20, iterations=1):
    """Draw rainbow that fades across all pixels at once."""
    for j in xrange(256*iterations):
        for i in xrange(strip.numPixels()):
            strip.setPixelColor(i, wheel((i+j) & 255))
        strip.show()
        time.sleep(wait_ms/1000.0)

def rainbowCycle(strip, wait_ms=20, iterations=5):
    """Draw rainbow that uniformly distributes itself across all pixels."""
    for j in xrange(256*iterations):
        for i in xrange(strip.numPixels()):
            strip.setPixelColor(i, wheel(((i * 256 / strip.numPixels()) + j) & 255))
        strip.show()
        time.sleep(wait_ms/1000.0)

def theaterChaseRainbow(strip, wait_ms=50):
    """Rainbow movie theater light style chaser animation."""
    for j in xrange(256):
        for q in xrange(3):
            for i in xrange(0, strip.numPixels(), 3):
                strip.setPixelColor(i+q, wheel((i+j) % 255))
            strip.show()
            time.sleep(wait_ms/1000.0)
            for i in xrange(0, strip.numPixels(), 3):
                strip.setPixelColor(i+q, 0)

def hsv(h, s, v):
    r,g,b = colorsys.hsv_to_rgb(h/360, s/255, v/255);
    return Color(int(r*255),int(g*255),int(b*255))

def gethsv(color):
    h,s,v = colorsys.rgb_to_hsv(float((color&0xff0000)>>16)/255.0, float((color&0xff00)>>8)/255.0, float(color&0xff)/255.0)
    return (h*360, s*255, v*255)

def inttorgb(i):
    r = (i & 0xff0000) >> 16
    g = (i & 0xff00) >> 8
    b = (i & 0xff)
    return [r, g, b]


def rgbtoint(i):
    return (i[0] << 16) | (i[1] << 8) | i[2]

def getColComp(i, c):
    return inttorgb(i)[c]

def setColComp(i, c, v):
    comps = inttorgb(i)
    comps[c] = v
    return rgbtoint(comps)


onAnimation = "nothing here"
buzzState = None
onBuzzColor = None
doBuzz = False
buzzFunc = None

SOLID_FRAMES = 40


target = [0] * LED_COUNT

PULSE_FRAMES = 30.0

def buzzPulse():
    global buzzState
    global doBuzz
    if buzzState == None:
        buzzState = PULSE_FRAMES;
    else:
        if (buzzState > 0):
            buzzState = buzzState-1
            for i in xrange(strip.numPixels()):
                strip.setPixelColor(i, hsv(gethsv(onBuzzColor)[0],gethsv(onBuzzColor)[1],255*buzzState/PULSE_FRAMES))
        else:
            for i in xrange(strip.numPixels()):
                strip.setPixelColor(i, Color(0,0,0))
            doBuzz = False
        strip.show()

STROBE_FRAMES=40
def buzzStrobe():
    global buzzState
    global doBuzz
    if buzzState == None:
        buzzState = STROBE_FRAMES;
    else:
        if (buzzState > 0):
            buzzState = buzzState-1

            val = (buzzState % 10) * 25
            r,g,b = inttorgb(onBuzzColor)
            newcol = rgbtoint([r * val, g * val, b * val])
            for i in xrange(strip.numPixels()):
                strip.setPixelColor(i, newcol)
        else:
            doBuzz = False
        strip.show()


chaseoffset = 0
def buzzChase():
    global buzzState
    global doBuzz
    global chaseoffset
    if buzzState == None:
        chaseoffset = random.randrange(0, LED_COUNT)
        for i in xrange(LED_COUNT):
            target[i] = 0
            strip.setPixelColor(i, Color(0,0,0))
        strip.show()
        buzzState = LED_COUNT;
    else:
        if (buzzState > 0):
            for i in xrange(30):
                buzzState = buzzState-1
                target[(buzzState+chaseoffset) % LED_COUNT] = onBuzzColor
            fade(30)
        else:
            doBuzz = False
        strip.show()


def buzzChase2():
    global buzzState
    global doBuzz
    global chaseoffset
    if buzzState == None:
        chaseoffset = random.randrange(0, LED_COUNT)
        for i in xrange(LED_COUNT):
            target[i] = 0
            strip.setPixelColor(i, Color(0,0,0))
        strip.show()
        buzzState = LED_COUNT;
    else:
        if (buzzState > 0):
            for i in xrange(25):
                buzzState = buzzState-1
                strip.setPixelColor((buzzState+chaseoffset) % LED_COUNT, onBuzzColor)
            fade(30)
        else:
            doBuzz = False
        strip.show()


buzzPossibilities = [buzzStrobe, buzzPulse, buzzChase, buzzChase2];
#buzzPossibilities = [buzzStrobe];

def fade(speed):
    for i in xrange(LED_COUNT):
        cur = strip.getPixelColor(i)
        tar = target[i]

        for c in xrange(3):
            curc = getColComp(cur, c)
            tarc = getColComp(tar, c)

            if abs(curc - tarc) <= speed:
                curc = tarc
            else:
                if(curc < tarc):
                    curc += speed
                else:
                    curc -= speed
            cur = setColComp(cur, c, curc)

        strip.setPixelColor(i, cur);
    strip.show()


def animationThread():
    global doBuzz
    global buzzFunc

    megamas = [0xFF0000, 0x00FF00, 0x0000FF]

    j = 0
    while True:
        #print onAnimation
        time.sleep(0.00001)
        if doBuzz:
            if buzzFunc == None:
                #gotta select a buzz
                buzzFunc = buzzPossibilities[random.randrange(0,len(buzzPossibilities))]
            else:
                buzzFunc()
        else:
            #not buzzing so animating
            if onAnimation == u'rainbow':
                j = j+1
                for i in xrange(strip.numPixels()):
                    strip.setPixelColor(i, wheel(((i * 256 / strip.numPixels()) + j) & 255))
                strip.show()
                time.sleep(0.00001)
            elif onAnimation == u'idle':
                time.sleep(0.00001)
                for i in xrange(60):
                    #target[random.randrange(0, strip.numPixels())] = wheel(random.randrange(0,256))
                    target[random.randrange(0, strip.numPixels())] = megamas[random.randrange(0, len(megamas))]
                fade(40)
                strip.show()
            elif onAnimation == u'black':
                for i in xrange(strip.numPixels()):
                    strip.setPixelColor(i, Color(0,0,0))
                strip.show()

def on_message(ws, message):
    global onAnimation
    global buzzState
    global onBuzzColor
    global doBuzz
    global buzzFunc
    print message
    msg = json.loads(message)
    print msg
    if (msg[u'cmd'] == u'setanimation'):
        onAnimation = msg[u'animation']
    elif (msg[u'cmd'] == u'buzz'):
        print "Buzz"
        onBuzzColor = Color(int(msg[u'r']),int(msg[u'g']),int(msg[u'b']));
        buzzState = None
        doBuzz = True
        buzzFunc = None

def on_error(ws, error):
    print error

def on_close(ws):
    print "### closed ###"

def on_open(ws):
    ws.send('{ "cmd": "hello from the rPi"}')

# Main program logic follows:
if __name__ == '__main__':
    # Create NeoPixel object with appropriate configuration.
    strip = Adafruit_NeoPixel(LED_COUNT, LED_PIN, LED_FREQ_HZ, LED_DMA, LED_INVERT, LED_BRIGHTNESS)
    strip.begin()

    websocket.enableTrace(True)
    thread.start_new_thread(animationThread, ())

    while True:
        try:
            ws = websocket.WebSocketApp("ws://192.168.1.64:8092",on_message = on_message,on_error = on_error,on_close = on_close)
            ws.on_open = on_open
            ws.run_forever()
        except (KeyboardInterrupt, SystemExit):
            raise
        except:
            pass
