add_library(fast_hsv2rgb STATIC fast_hsv2rgb_32bit.c)
add_library(ws2812 STATIC ws2812.c)
target_link_libraries(ws2812 fast_hsv2rgb)
