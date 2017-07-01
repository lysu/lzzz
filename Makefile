OPT ?= -O2 -g2 -DNDEBUG

$(shell CC="$(CC)" CXX="$(CXX)" TARGET_OS="$(TARGET_OS)" \
	./build_detect_platform build_config.mk ./)

include build_config.mk

TESTS = \

UTILS = \

PROGNAMES := $(notdir $(TEST) $(UTILS))

BENCHMARKS = \

CFLAGS += -I. -I./include $(PLATFORM_CCFLAGS) $(OPT)
CXXFLAGS += -I. -I./include $(PLATFORM_CXXFLAGS) $(OPT)

LDFLAGS += $(PLATFORM_LDFLAGS)
LIBS += $(PLATFORM_LIBS)

SIMULATOR_OUTDIR=out-ios-x86
DEVICE_OUTDIR=out-ios-arm

STATIC_OUTDIR=out-static
SHARED_OUTDIR=out-shared
STATIC_PROGRAMS := $(addprefix $(STATIC_OUTDIR)/, $(PROGNAMES))
STATIC_LIBOBJECTS := $(addprefix $(STATIC_OUTDIR)/, $(SOURCES:.cc=.o))

DEVICE_LIBOBJECTS := $(addprefix $(DEVICE_OUTDIR)/, $(SOURCES:.cc=.o))

SIMULATOR_LIBOBJECTS := $(addprefix $(SIMULATOR_OUTDIR)/, $(SOURCES:.cc=.o))

SHARED_LIBOBJECTS := $(addprefix $(SHARED_OUTDIR)/, $(SOURCES:.cc=.o))

TESTUTIL := $(STATIC_OUTDIR)/util/testutil.o
TESTHARNESS := $(STATIC_OUTDIR)/util/testharness.o $(TESTUTIL)

STATIC_TESTOBJS := $(addprefix $(STATIC_OUTDIR)/, $(addsuffix .o, $(TESTS)))
STATIC_UTILOBJS := $(addprefix $(STATIC_OUTDIR)/, $(addsuffix .o, $(UTILS)))
STATIC_ALLOBJS := $(STATIC_LIBOBJECTS) $(STATIC_TESTOBJS) $(STATIC_UTILOBJS) $(TESTHARNESS)
DEVICE_ALLOBJS := $(DEVICE_LIBOBJECTS)
SIMULATOR_ALLOBJS := $(SIMULATOR_LIBOBJECTS)

default: all

ifneq ($(PLATFORM_SHARED_EXT),)

SHARED_ALLOBJS := $(SHARED_LIBOBJECTS) $(TESTHARNESS)

ifneq ($(PLATFORM_SHARED_VERSIONED),true)
SHARED_LIB1 = liblzzz.$(PLATFORM_SHARED_EXT)
SHARED_LIB2 = $(SHARED_LIB1)
SHARED_LIB3 = $(SHARED_LIB1)
SHARED_LIBS = $(SHARED_LIB1)
SHARED_MEMENVLIB = $(SHARED_OUTDIR)/libmemenv.a
else
SHARED_VERSION_MAJOR = 1
SHARED_VERSION_MINOR = 1 
SHARED_LIB1 = liblzzz.$(PLATFORM_SHARED_EXT)
SHARED_LIB2 = $(SHARED_LIB1).$(SHARED_VERSION_MAJOR)
SHARED_LIB3 = $(SHARED_LIB1).$(SHARED_VERSION_MAJOR).$(SHARED_VERSION_MINOR)
SHARED_LIBS = $(SHARED_OUTDIR)/$(SHARED_LIB1) $(SHARED_OUTDIR)/$(SHARED_LIB2) $(SHARED_OUTDIR)/$(SHARED_LIB3)
$(SHARED_OUTDIR)/$(SHARED_LIB1): $(SHARED_OUTDIR)/$(SHARED_LIB3)
	ln -fs $(SHARED_LIB3) $(SHARED_OUTDIR)/$(SHARED_LIB1)
$(SHARED_OUTDIR)/$(SHARED_LIB2): $(SHARED_OUTDIR)/$(SHARED_LIB3)
	ln -fs $(SHARED_LIB3) $(SHARED_OUTDIR)/$(SHARED_LIB2)
SHARED_MEMENVLIB = $(SHARED_OUTDIR)/libmemenv.a
endif

$(SHARED_OUTDIR)/$(SHARED_LIB3): $(SHARED_LIBOBJECTS)
	$(CXX) $(LDFLAGS) $(PLATFORM_SHARED_LDFLAGS)$(SHARED_LIB2) $(SHARED_LIBOBJECTS) -o $(SHARED_OUTDIR)/$(SHARED_LIB3) $(LIBS)
endif

all: $(SHARED_LIBS) $(SHARED_PROGRAMS) $(STATIC_OUTDIR)/liblzzz.a $(STATIC_PROGRAMS) main

main: $(STATIC_OUTDIR)/liblzzz.a main.cc 
	$(CXX) $(LDFLAGS) $(CXXFLAGS) $^ -o $@

check: $(STATIC_PROGRAMS)
	for t in $(notdir $(TESTS)); do echo "***** Running $$t"; $(STATIC_OUTDIR)/$$t || exit 1; done

clean:
	-rm -rf out-static out-shared out-ios-x86 out-ios-arm out-ios-universal
	-rm -f build_config.mk
	-rm -rf ios-x86 ios-arm

$(STATIC_OUTDIR):
	mkdir $@

$(STATIC_OUTDIR)/core: | $(STATIC_OUTDIR)
	mkdir $@

$(STATIC_OUTDIR)/port: | $(STATIC_OUTDIR)
	mkdir $@

.PHONY: STATIC_OBJDIRS
STATIC_OBJDIRS: \
	$(STATIC_OUTDIR)/core \
	$(STATIC_OUTDIR)/port 

$(SHARED_OUTDIR):
	mkdir $@

$(SHARED_OUTDIR)/core: | $(SHARED_OUTDIR)
	mkdir $@

$(SHARED_OUTDIR)/port: | $(SHARED_OUTDIR)
	mkdir $@

.PHONY: SHARED_OBJDIRS
SHARED_OBJDIRS: \
	$(SHARED_OUTDIR)/core \
	$(SHARED_OUTDIR)/port

$(DEVICE_OUTDIR):
	mkdir $@

$(DEVICE_OUTDIR)/core: | $(DEVICE_OUTDIR)
	mkdir $@

$(DEVICE_OUTDIR)/port: | $(DEVICE_OUTDIR)
	mkdir $@

.PHONY: DEVICE_OBJDIRS
DEVICE_OBJDIRS: \
	$(DEVICE_OUTDIR)/core \
	$(DEVICE_OUTDIR)/port

$(SIMULATOR_OUTDIR):
	mkdir $@

$(SIMULATOR_OUTDIR)/core: | $(SIMULATOR_OUTDIR)
	mkdir $@

$(SIMULATOR_OUTDIR)/port: | $(SIMULATOR_OUTDIR)
	mkdir $@

.PHONY: SIMULATOR_OBJDIRS
SIMULATOR_OBJDIRS: \
	$(SIMULATOR_OUTDIR)/core \
	$(SIMULATOR_OUTDIR)/port 

$(STATIC_ALLOBJS): | STATIC_OBJDIRS
$(DEVICE_ALLOBJS): | DEVICE_OBJDIRS
$(SIMULATOR_ALLOBJS): | SIMULATOR_OBJDIRS
$(SHARED_ALLOBJS): | SHARED_OBJDIRS

ifeq ($(PLATFORM), IOS)
$(DEVICE_OUTDIR)/liblzzz.a: $(DEVICE_LIBOBJECTS)
	rm -f $@
	$(AR) -rs $@ $(DEVICE_LIBOBJECTS)

$(SIMULATOR_OUTDIR)/liblzzz.a: $(SIMULATOR_LIBOBJECTS)
	rm -f $@
	$(AR) -rs $@ $(SIMULATOR_LIBOBJECTS)

$(STATIC_OUTDIR)/liblzzz.a: $(STATIC_OUTDIR) $(DEVICE_OUTDIR)/liblzzz.a $(SIMULATOR_OUTDIR)/liblzzz.a
	lipo -create $(DEVICE_OUTDIR)/liblzzz.a $(SIMULATOR_OUTDIR)/liblzzz.a -output $@

else

$(STATIC_OUTDIR)/liblzzz.a:$(STATIC_LIBOBJECTS)
	rm -f $@
	$(AR) -rs $@ $(STATIC_LIBOBJECTS)

endif

$(SIMULATOR_OUTDIR)/%.o: %.cc
	xcrun -sdk iphonesimulator $(CXX) $(CXXFLAGS) $(SIMULATOR_CFLAGS) -c $< -o $@

$(DEVICE_OUTDIR)/%.o: %.cc
	xcrun -sdk iphoneos $(CXX) $(CXXFLAGS) $(DEVICE_CFLAGS) -c $< -o $@

$(SIMULATOR_OUTDIR)/%.o: %.c
	xcrun -sdk iphonesimulator $(CC) $(CFLAGS) $(SIMULATOR_CFLAGS) -c $< -o $@

$(DEVICE_OUTDIR)/%.o: %.c
	xcrun -sdk iphoneos $(CC) $(CFLAGS) $(DEVICE_CFLAGS) -c $< -o $@

$(STATIC_OUTDIR)/%.o: %.cc
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(STATIC_OUTDIR)/%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

$(SHARED_OUTDIR)/%.o: %.cc
	$(CXX) $(CXXFLAGS) $(PLATFORM_SHARED_CFLAGS) -c $< -o $@

$(SHARED_OUTDIR)/%.o: %.c
	$(CC) $(CFLAGS) $(PLATFORM_SHARED_CFLAGS) -c $< -o $@

$(STATIC_OUTDIR)/port/port_posix_sse.o: port/port_posix_sse.cc
	$(CXX) $(CXXFLAGS) $(PLATFORM_SSEFLAGS) -c $< -o $@

$(SHARED_OUTDIR)/port/port_posix_sse.o: port/port_posix_sse.cc
	$(CXX) $(CXXFLAGS) $(PLATFORM_SHARED_CFLAGS) $(PLATFORM_SSEFLAGS) -c $< -o $@

