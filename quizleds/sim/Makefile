# Builds the quizleds firmware as host executables: ledsim for the string, treesim for the desk
# trees. See README.md.
#
# The firmware sources in ../src/string and ../src/tree, and the shared ones in ../src, are compiled
# unchanged; everything ESP-specific is satisfied by the headers in shim/, which come first on
# the include path.

CXX      ?= c++
CXXFLAGS ?= -O2 -g -std=c++11 -Wall -Wextra -Wno-unused-parameter
LDFLAGS  ?=

SRCDIR   := ../src
STRDIR   := $(SRCDIR)/string
SHIMDIR  := shim
BUILDDIR := build
TREEDIR  := $(SRCDIR)/tree
TARGET   := $(BUILDDIR)/ledsim
TREESIM  := $(BUILDDIR)/treesim

# NeoPixelBus' colour classes are compiled from the library's own sources so that colour
# conversion is bit-identical to the board. PlatformIO puts them here; it is gitignored,
# so a fresh checkout needs `pio pkg install -e main` in ../ first.
NPB      := ../.pio/libdeps/main/NeoPixelBus/src
NPBCOLOR := $(NPB)/internal/colors

# The string and the trees share no header names, so one include path serves both and the
# shims and net.cpp are compiled once for the two
INCLUDES := -I$(SHIMDIR) -I$(STRDIR) -I$(TREEDIR) -I$(SRCDIR) -I$(NPB)

FIRMWARE := $(STRDIR)/main.cpp $(STRDIR)/animation.cpp $(STRDIR)/ledmapping.cpp $(STRDIR)/web.cpp \
            $(SRCDIR)/net.cpp
SIM      := simmain.cpp frameshm.cpp $(SHIMDIR)/arduino_shim.cpp $(SHIMDIR)/esp_websocket_client.cpp \
            $(SHIMDIR)/freertos_shim.cpp
COLOURS  := $(NPBCOLOR)/RgbColor.cpp $(NPBCOLOR)/RgbColorBase.cpp \
            $(NPBCOLOR)/HslColor.cpp $(NPBCOLOR)/HsbColor.cpp

TREEFW   := $(TREEDIR)/tree_main.cpp $(TREEDIR)/tree_anim.cpp $(SRCDIR)/net.cpp
TREESIMS := treesim.cpp $(SHIMDIR)/arduino_shim.cpp $(SHIMDIR)/esp_websocket_client.cpp \
            $(SHIMDIR)/freertos_shim.cpp
TREECOL  := $(COLOURS) $(NPBCOLOR)/NeoGammaTableMethod.cpp

OBJS     := $(patsubst %.cpp,$(BUILDDIR)/%.o,$(notdir $(FIRMWARE) $(SIM) $(COLOURS)))
TREEOBJS := $(patsubst %.cpp,$(BUILDDIR)/%.o,$(notdir $(TREEFW) $(TREESIMS) $(TREECOL)))
VPATH := $(STRDIR):$(TREEDIR):$(SRCDIR):$(SHIMDIR):$(NPBCOLOR):.

.PHONY: all clean run run-trees check-deps

all: check-deps $(TARGET) $(TREESIM)

check-deps:
	@test -d "$(NPB)" || { \
		echo "ledsim: NeoPixelBus not found at $(NPB)"; \
		echo "        run 'pio pkg install -e main' in $(abspath ..) first"; \
		exit 1; }

$(TARGET): $(OBJS)
	$(CXX) $(CXXFLAGS) $^ -o $@ $(LDFLAGS)

$(TREESIM): $(TREEOBJS)
	$(CXX) $(CXXFLAGS) $^ -o $@ $(LDFLAGS)

# -MMD writes a .d file beside each object listing every header it included, and -MP adds an
# empty rule for each header so that deleting one does not break the build. Objects also
# depend on this Makefile, so editing its flags or file lists rebuilds everything.
$(BUILDDIR)/%.o: %.cpp Makefile | $(BUILDDIR)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -MMD -MP -c $< -o $@

-include $(sort $(OBJS:.o=.d) $(TREEOBJS:.o=.d))

$(BUILDDIR):
	@mkdir -p $(BUILDDIR)

run: all
	$(TARGET)

run-trees: all
	$(TREESIM)

clean:
	rm -rf $(BUILDDIR)
