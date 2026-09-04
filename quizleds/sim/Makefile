# Builds the quizleds firmware as a host executable. See README.md.
#
# The firmware sources in ../src are compiled unchanged; everything ESP-specific is
# satisfied by the headers in shim/, which come first on the include path.

CXX      ?= c++
CXXFLAGS ?= -O2 -g -std=c++11 -Wall -Wextra -Wno-unused-parameter
LDFLAGS  ?=

SRCDIR   := ../src
SHIMDIR  := shim
BUILDDIR := build
TARGET   := $(BUILDDIR)/ledsim

# NeoPixelBus' colour classes are compiled from the library's own sources so that colour
# conversion is bit-identical to the board. PlatformIO puts them here; it is gitignored,
# so a fresh checkout needs `pio pkg install -e main` in ../ first.
NPB      := ../.pio/libdeps/main/NeoPixelBus/src
NPBCOLOR := $(NPB)/internal/colors

INCLUDES := -I$(SHIMDIR) -I$(SRCDIR) -I$(NPB)

FIRMWARE := $(SRCDIR)/main.cpp $(SRCDIR)/animation.cpp $(SRCDIR)/ledmapping.cpp $(SRCDIR)/web.cpp
SIM      := simmain.cpp $(SHIMDIR)/arduino_shim.cpp $(SHIMDIR)/esp_websocket_client.cpp
COLOURS  := $(NPBCOLOR)/RgbColor.cpp $(NPBCOLOR)/RgbColorBase.cpp \
            $(NPBCOLOR)/HslColor.cpp $(NPBCOLOR)/HsbColor.cpp

OBJS := $(patsubst %.cpp,$(BUILDDIR)/%.o,$(notdir $(FIRMWARE) $(SIM) $(COLOURS)))
VPATH := $(SRCDIR):$(SHIMDIR):$(NPBCOLOR):.

.PHONY: all clean run check-deps

all: check-deps $(TARGET)

check-deps:
	@test -d "$(NPB)" || { \
		echo "ledsim: NeoPixelBus not found at $(NPB)"; \
		echo "        run 'pio pkg install -e main' in $(abspath ..) first"; \
		exit 1; }

$(TARGET): $(OBJS)
	$(CXX) $(CXXFLAGS) $^ -o $@ $(LDFLAGS)

$(BUILDDIR)/%.o: %.cpp | $(BUILDDIR)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

$(BUILDDIR):
	@mkdir -p $(BUILDDIR)

run: all
	$(TARGET)

clean:
	rm -rf $(BUILDDIR)
