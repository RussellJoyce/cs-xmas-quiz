add_executable(ledtest ledtest.c)
target_link_libraries(ledtest ws2812)

add_executable(hsvtest hsvtest.c)
target_link_libraries(hsvtest ws2812)

add_executable(megamas megamas.c)
target_link_libraries(megamas ws2812)
