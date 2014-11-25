/* Teensyduino Core Library
 * http://www.pjrc.com/teensy/
 * Copyright (c) 2013 PJRC.COM, LLC.
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * 1. The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * 2. If the Software is incorporated into a build system that allows
 * selection among a list of target devices, then similar target
 * devices manufactured by PJRC.COM must be included in the list of
 * target devices and selectable in the same manner.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#ifndef USBquiz_h_
#define USBquiz_h_

#if defined(USB_QUIZ)

#include <inttypes.h>

// C language implementation
#ifdef __cplusplus
extern "C" {
#endif
int usb_quiz_send(void);
extern uint32_t usb_quiz_data[1];
#ifdef __cplusplus
}
#endif

// C++ interface
#ifdef __cplusplus
class usb_quiz_class
{
    public:
    void begin(void) { }
    void end(void) { }
    void button(uint8_t button, bool val) {
        if (--button >= 8) return;
        if (val) usb_quiz_data[0] |= (1 << button);
        else usb_quiz_data[0] &= ~(1 << button);
        if (!manual_mode) usb_quiz_send();
    }
    void useManualSend(bool mode) {
        manual_mode = mode;
    }
    void send_now(void) {
        usb_quiz_send();
    }
    private:
    static uint8_t manual_mode;
};
extern usb_quiz_class Quiz;

#endif // __cplusplus

#endif // USB_QUIZ
#endif // USBquiz_h_

