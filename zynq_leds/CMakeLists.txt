cmake_minimum_required(VERSION 3.0)
project(leds C)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=gnu11 -Wstrict-prototypes -Wmissing-prototypes -Wall -Wextra -O3")
set(CMAKE_C_COMPILER "gcc")

# Fix include directories
include_directories(${CMAKE_SOURCE_DIR}/include/)
set(INCLUDE_DIRECTORIES ${CMAKE_SOURCE_DIR}/include/)

add_subdirectory(libs)
add_subdirectory(tests)

# Target to rsync files and make on ZynqBerry
add_custom_target(
        zynqberry
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMAND rsync -druvh CMakeLists.txt include libs tests zynqberry:~/leds
        COMMAND ssh zynqberry 'cd ~/leds && mkdir -p build && cd build && cmake .. && make'
)
