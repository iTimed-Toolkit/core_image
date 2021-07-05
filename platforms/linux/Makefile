# Various project paths

PROJECT_ROOT          := /root
PLATFORM_ROOT         := $(PROJECT_ROOT)/platforms/linux

SANDCASTLE_ROOT       := $(PROJECT_ROOT)/sources/sandcastle
SANDCASTLE_BUILD_ROOT := $(SANDCASTLE_ROOT)/sandcastle-buildroot
SANDCASTLE_LOAD_ROOT  := $(SANDCASTLE_ROOT)/projectsandcastle/loader
KERNEL_ROOT           := $(SANDCASTLE_ROOT)/linux-sandcastle

PONGO_ROOT            := $(PROJECT_ROOT)/sources/pongoOS

# Boot targets

boot: images
	$(PLATFORM_ROOT)/scripts/stage1_checkra1n.sh $(PLATFORM_ROOT)/images/Pongo.bin
	$(PLATFORM_ROOT)/scripts/stage2_wait.sh 10

	sudo $(PLATFORM_ROOT)/tools/load-linux     \
            $(PLATFORM_ROOT)/images/Image.lzma \
            $(PLATFORM_ROOT)/images/dtbpack

images: $(PLATFORM_ROOT)/images/Pongo.bin    \
            $(PLATFORM_ROOT)/tools/load-linux  \
            $(PLATFORM_ROOT)/images/Image.lzma \
            $(PLATFORM_ROOT)/images/dtbpack

# Images - Pongo

$(PLATFORM_ROOT)/images/Pongo.bin:
	make -C $(PONGO_ROOT)
	mkdir -p $(PLATFORM_ROOT)/images
	rm -f $(PLATFORM_ROOT)/images/Pongo.bin
	ln -s $(PONGO_ROOT)/build/Pongo.bin $(PLATFORM_ROOT)/images/Pongo.bin

rebuild-pongo:
	make -C $(PONGO_ROOT)

# Images - Linux

$(PLATFORM_ROOT)/images/Image.lzma: $(SANDCASTLE_BUILD_ROOT)/output/images/Image.lzma
	mkdir -p $(PLATFORM_ROOT)/images
	rm -f $(PLATFORM_ROOT)/images/Image.lzma
	ln -s $(SANDCASTLE_BUILD_ROOT)/output/images/Image.lzma $(PLATFORM_ROOT)/images/Image.lzma

$(SANDCASTLE_BUILD_ROOT)/output/images/Image.lzma: $(SANDCASTLE_BUILD_ROOT)/output/images/Image
	lzma -kzvf $(SANDCASTLE_BUILD_ROOT)/output/images/Image

$(SANDCASTLE_BUILD_ROOT)/output/images/Image: $(KERNEL_ROOT)
	make -C $(SANDCASTLE_BUILD_ROOT) linux-rebuild
	make -C $(SANDCASTLE_BUILD_ROOT)

$(PLATFORM_ROOT)/images/dtbpack: $(SANDCASTLE_BUILD_ROOT)/output/images/Image
	python3 $(PLATFORM_ROOT)/scripts/pack.py $(SANDCASTLE_BUILD_ROOT)/output/build/linux/arch/arm64/boot/dts/hx/
	mkdir -p $(PLATFORM_ROOT)/images/
	mv dtbpack $(PLATFORM_ROOT)/images/

rebuild-sandcastle:
	make -C $(SANDCASTLE_BUILD_ROOT)

rebuild-kernel:
	touch $(KERNEL_ROOT)

# Tools

$(PLATFORM_ROOT)/tools/load-linux : $(SANDCASTLE_LOAD_ROOT)/load-linux.c
	mkdir -p $(PLATFORM_ROOT)/tools/
	gcc -o $(PLATFORM_ROOT)/tools/load-linux $(SANDCASTLE_LOAD_ROOT)/load-linux.c -lusb-1.0

# Clean targets

clean:
	rm -f $(PLATFORM_ROOT)/images/dtbpack       \
             $(PLATFORM_ROOT)/images/Image.lzma \
             $(PLATFORM_ROOT)/images/Pongo.bin
	rm -rf $(PLATFORM_ROOT)/tools

source-clean:
	make -C $(PONGO_ROOT) clean
	make -C $(SANDCASTLE_BUILD_ROOT) clean
	rm -rf $(SANDCASTLE_BUILD_ROOT)/dl
