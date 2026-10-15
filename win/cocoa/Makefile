# Builds NetHack.app (Cocoa window port) against the NetHack 5.0 core.
#
# Prerequisites, run once from the top of the tree:
#   (cd sys/unix && sh setup.sh hints/macOS.500) && make fetch-lua && make all
# which builds liblua, makedefs, dlb, nhdat and util/tilemap; this Makefile
# then generates src/tile.c and the tile sheet and builds the app.
#
#   make -C win/cocoa          # -> win/cocoa/build/NetHack.app
#   make -C win/cocoa run

TOP      := ../..
BUILD    := build
OBJDIR   := $(BUILD)/obj
APP      := $(BUILD)/NetHack.app
CONTENTS := $(APP)/Contents

CC       := xcrun clang
IBTOOL   := xcrun ibtool
ICONUTIL := iconutil

MACOSX_DEPLOYMENT_TARGET ?= 12.0
ARCHFLAGS ?= -arch $(shell uname -m)

# Must stay in step with the feature flags util/tilemap was built with
# (NOMAIL in particular), or tile indices in src/tile.c will be off.
NHDEFS := -DNOTPARMDECL -DDLB -DSYSCF -DSYSCF_FILE=\"sysconf\" -DNOMAIL \
          -DNOCWD_ASSUMPTIONS \
          -DNOTTYGRAPHICS -DCOCOA_GRAPHICS -DTILES_IN_GLYPHMAP \
          -DDEFAULT_WINDOW_SYS=\"cocoa\" -DGREPPATH=\"/usr/bin/grep\"

COMMONFLAGS := -g -O1 $(ARCHFLAGS) -mmacosx-version-min=$(MACOSX_DEPLOYMENT_TARGET) \
               -I. -IiHack -I$(TOP)/include $(NHDEFS)
CFLAGS   := $(COMMONFLAGS) -std=c99 -w
OBJCFLAGS := $(COMMONFLAGS) -fobjc-arc -Wno-deprecated-declarations \
             -include NetHackCocoa_Prefix.pch
LDFLAGS  := $(ARCHFLAGS) -mmacosx-version-min=$(MACOSX_DEPLOYMENT_TARGET) \
            -framework Cocoa -framework AVFoundation -framework Carbon

CORE_SRC := allmain alloc apply artifact attrib ball bones botl calendar \
	cfgfiles cmd coloratt date dbridge decl detect dig display dlb do_name \
	do_wear do dog dogmove dokick dothrow drawing dungeon earlyarg eat end \
	engrave exper explode extralev files fountain getpos glyphs hack \
	hacklib iactions insight invent isaac64 light lock mail makemon mcastu \
	mdlib mhitm mhitu minion mklev mkmap mkmaze mkobj mkroom mon mondata \
	monmove monst mplayer mthrowu muse music nhlobj nhlsel nhlua nhmd4 \
	o_init objects objnam options pager pickup pline polyself potion pray \
	priest quest questpgr read rect region report restore rip rnd role \
	rumors save selvar sfbase sfstruct shk shknam sit sounds sp_lev spell \
	stairs steal steed strutil symbols sys teleport tile timeout topten \
	track trap u_init uhitm utf8map vault version vision weapon were wield \
	windows wizard wizcmds worm worn write zap
SYS_SRC  := $(TOP)/sys/share/posixregex.c $(TOP)/sys/unix/unixmain.c \
	$(TOP)/sys/unix/unixres.c $(TOP)/sys/unix/unixunix.c

COCOA_C  := $(wildcard *.c)
COCOA_M  := $(wildcard *.m) $(wildcard iHack/*.m)

OBJS := $(addprefix $(OBJDIR)/,$(addsuffix .o,$(CORE_SRC))) \
	$(addprefix $(OBJDIR)/,$(notdir $(SYS_SRC:.c=.o))) \
	$(addprefix $(OBJDIR)/cocoa_,$(notdir $(COCOA_C:.c=.o))) \
	$(addprefix $(OBJDIR)/cocoa_,$(notdir $(COCOA_M:.m=.o)))

LUALIB := $(wildcard $(TOP)/lib/lua/liblua-*.a)

XIBS := $(wildcard en.lproj/*.xib)
NIBS := $(patsubst en.lproj/%.xib,$(CONTENTS)/Resources/en.lproj/%.nib,$(XIBS))

DATA := $(TOP)/dat/nhdat $(TOP)/dat/license $(TOP)/dat/symbols sysconf \
	Credits.rtf $(wildcard Resources/images/*.png) $(BUILD)/tiles16.bmp

.PHONY: all app run clean

all: app

app: $(CONTENTS)/MacOS/NetHack $(NIBS) $(CONTENTS)/Info.plist \
	$(CONTENTS)/Resources/nethack.icns resources

vpath %.c $(TOP)/src $(TOP)/sys/share $(TOP)/sys/unix

$(OBJDIR)/%.o: %.c | $(OBJDIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJDIR)/cocoa_%.o: %.c | $(OBJDIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJDIR)/cocoa_%.o: %.m | $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c $< -o $@

$(OBJDIR)/cocoa_%.o: iHack/%.m | $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c $< -o $@

$(TOP)/src/tile.c: $(TOP)/win/share/tilemap.c $(TOP)/win/share/monsters.txt \
	$(TOP)/win/share/objects.txt $(TOP)/win/share/other.txt
	$(MAKE) -C $(TOP)/util ../src/tile.c

$(BUILD)/tiles16.bmp: $(TOP)/win/share/monsters.txt $(TOP)/win/share/objects.txt \
	$(TOP)/win/share/other.txt | $(BUILD)
	$(MAKE) -C $(TOP)/util tile2bmp
	cd $(TOP)/util && ./tile2bmp $(CURDIR)/$@

$(OBJDIR)/tile.o: $(TOP)/src/tile.c

$(CONTENTS)/MacOS/NetHack: $(OBJS) $(LUALIB)
	@mkdir -p $(@D)
	$(CC) $(LDFLAGS) -o $@ $(OBJS) $(LUALIB)

$(CONTENTS)/Resources/en.lproj/%.nib: en.lproj/%.xib
	@mkdir -p $(@D)
	$(IBTOOL) --errors --output-format human-readable-text \
		--minimum-deployment-target $(MACOSX_DEPLOYMENT_TARGET) \
		--compile $@ $<

$(CONTENTS)/Info.plist: NetHack-Info.plist
	@mkdir -p $(@D)
	sed -e 's/\$${EXECUTABLE_NAME}/NetHack/' \
	    -e 's/\$$(PRODUCT_BUNDLE_IDENTIFIER)/net.hack.cocoa.NetHack5/' \
	    -e 's/\$${PRODUCT_NAME}/NetHack/' \
	    -e 's/\$$(PRODUCT_BUNDLE_PACKAGE_TYPE)/APPL/' \
	    -e 's/\$$(MARKETING_VERSION)/5.0.0/' \
	    -e 's/\$$(CURRENT_PROJECT_VERSION)/1/' \
	    -e 's/\$${MACOSX_DEPLOYMENT_TARGET}/$(MACOSX_DEPLOYMENT_TARGET)/' \
	    $< > $@

$(CONTENTS)/Resources/nethack.icns: Resources/images/nethack.iconset
	@mkdir -p $(@D)
	$(ICONUTIL) -c icns -o $@ $<

resources: $(DATA) $(CONTENTS)/MacOS/NetHack
	@mkdir -p $(CONTENTS)/Resources
	cp -f $(DATA) $(CONTENTS)/Resources/
	codesign --force --sign - --entitlements NetHack.entitlements $(APP)

run: app
	$(CONTENTS)/MacOS/NetHack

$(OBJDIR) $(BUILD):
	mkdir -p $@

clean:
	rm -rf $(BUILD)
