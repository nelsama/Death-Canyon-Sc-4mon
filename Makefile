CC65_HOME ?= D:/cc65
CA65 = $(CC65_HOME)/bin/ca65.exe
LD65 = $(CC65_HOME)/bin/ld65.exe
# Variantes de prueba, combinables:
#   TURBO=1     scroll rápido, no muere y jefes con 5 de vida
#   INMORTAL=1  velocidad normal, sin morir
#   AMENAZA=n   empieza con esa amenaza (0-39)
V =
DEF =
ifeq ($(TURBO),1)
V := $(V)turbo
DEF += -D TURBO=1
endif
ifeq ($(INMORTAL),1)
V := $(V)inmortal
DEF += -D INMORTAL=1
endif
ifneq ($(AMENAZA),)
V := $(V)amenaza$(AMENAZA)
DEF += -D AMENAZA_INI=$(AMENAZA)
endif
B = build$(if $(V),/$(V))
O = output$(if $(V),/$(V))
OBJS = $(addprefix $(B)/,main.o menu.o video.o terrain.o player.o enemies.o sound.o hud.o input.o data.o)
BIN  = $(O)/dcanyon.bin

all: $(BIN)
	@ls -l $(BIN)

build/gfx.inc: gfx/tiles.txt tools/gfx.py
	@mkdir -p build output
	python tools/gfx.py gfx/tiles.txt $@

$(B)/%.o: src/%.s src/hardware.s build/gfx.inc
	@mkdir -p $(B) $(O)
	$(CA65) -t none --cpu 6502 $(DEF) -I src -I build -g -o $@ $<

# main.o va primero: el monitor entra por $0800.
$(BIN): $(OBJS) config/dcanyon.cfg
	$(LD65) -C config/dcanyon.cfg -m $(O)/dcanyon.map --dbgfile $(O)/dcanyon.dbg -o $@ $(OBJS)

clean:
	rm -rf build output
.PHONY: all clean
