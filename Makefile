PYTHON ?= python3
LWASM ?= lwasm
ASFLAGS = --6809 --format=raw

.PHONY: all check clean
all: build/diag_2d.d88 build/diag_2hd.d88

build:
	mkdir -p build

build/rom_2d.bin: rom/boot6809.asm | build
	$(LWASM) $(ASFLAGS) -DHD=0 -o $@ $<
build/rom_2hd.bin: rom/boot6809.asm | build
	$(LWASM) $(ASFLAGS) -DHD=1 -o $@ $<
build/ipl_2d.bin: ipl/boot_ipl.asm | build
	$(LWASM) $(ASFLAGS) -DHD=0 -o $@ $<
build/ipl_2hd.bin: ipl/boot_ipl.asm | build
	$(LWASM) $(ASFLAGS) -DHD=1 -o $@ $<
build/minimal.bin: os/minimal.asm | build
	$(LWASM) $(ASFLAGS) -o $@ $<

build/.images: build/rom_2d.bin build/rom_2hd.bin build/ipl_2d.bin build/ipl_2hd.bin build/minimal.bin tools/make_images.py
	$(PYTHON) tools/make_images.py --build build
	touch $@

build/diag_2d.d88 build/diag_2hd.d88: build/.images
	@test -f $@

check: all
	$(PYTHON) -m unittest discover -s tests -v

clean:
	rm -rf build
