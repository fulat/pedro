# CMake owns compilation and the OS image pipeline.
BUILD_DIR := build
GUI_BUILD_DIR := $(BUILD_DIR)/dev
FULL_BUILD_DIR := $(BUILD_DIR)/all
GUI_EXECUTABLE := $(GUI_BUILD_DIR)/gui/pedro-gui
JOBS ?= 4
DEV_CMAKE_ARGS ?=

ifeq ($(shell id -u),0)
SUDO :=
else
SUDO := sudo
endif

.DEFAULT_GOAL := image
.PHONY: help setup gnome host-check config build gui-config gui-build gui dev start GUI qml diagnose compositor image-config stage verify image clean

help:
	@echo "make gui | dev | start | GUI   Compile and open the GUI"
	@echo "make gui-config  Configure GUI development in build/dev"
	@echo "make gui-build   Compile PAPI and GUI only"
	@echo "make config      Configure all development components in build/all"
	@echo "make build       Compile PAPI, GUI, compositor and installer"
	@echo "make qml         Open the existing GUI binary with source QML"
	@echo "make diagnose    Compile and open the GUI with rendering diagnostics"
	@echo "make compositor  Compile and run the compositor"
	@echo "make setup       Install Ubuntu development dependencies"
	@echo "make gnome       Install the Pedro GNOME integration"
	@echo "make image       Build build/images/pedro.img (also the default)"
	@echo "make image-config | stage | verify | clean"

setup:
	./setup.sh

gnome:
	python3 gnome/application/install.py

# $(1): output directory; $(2): privilege prefix; $(3): CMake options.
# Never silently delete a build directory belonging to a different checkout.
define configure
	@if test -f "$(1)/CMakeCache.txt" && ! grep -Fqx "CMAKE_HOME_DIRECTORY:INTERNAL=$(CURDIR)" "$(1)/CMakeCache.txt"; then \
		echo "$(1) belongs to a different source path; clean that directory before continuing."; \
		exit 1; \
	fi
	$(2) cmake -S . -B "$(1)" -G Ninja $(3)
endef

gui-config:
	$(call configure,$(GUI_BUILD_DIR),,-DPEDRO_BUILD_IMAGE=OFF -DPEDRO_BUILD_COMPOSITOR=OFF -DPEDRO_BUILD_INSTALLER=OFF $(DEV_CMAKE_ARGS))

gui-build: gui-config
	cmake --build "$(GUI_BUILD_DIR)" --target pedro_gui --parallel $(JOBS)

gui dev start GUI: gui-config
	cmake --build "$(GUI_BUILD_DIR)" --target pedro-gui-run --parallel $(JOBS)

config:
	$(call configure,$(FULL_BUILD_DIR),,-DPEDRO_BUILD_IMAGE=OFF -DPEDRO_BUILD_COMPOSITOR=ON -DPEDRO_BUILD_INSTALLER=ON $(DEV_CMAKE_ARGS))

build: config
	cmake --build "$(FULL_BUILD_DIR)" --parallel $(JOBS)

qml:
	@test -x "$(GUI_EXECUTABLE)" || { echo "Run 'make gui-build' once before 'make qml'."; exit 1; }
	PEDRO_DEVELOPMENT_MODE=1 PEDRO_QML_DIR="$(CURDIR)/gui" "$(GUI_EXECUTABLE)"

diagnose: gui-build
	PEDRO_DEVELOPMENT_MODE=1 PEDRO_RENDER_DIAGNOSTICS=1 QSG_INFO=1 \
		PEDRO_QML_DIR="$(CURDIR)/gui" "$(GUI_EXECUTABLE)"

compositor: config
	cmake --build "$(FULL_BUILD_DIR)" --target pedro_compositor --parallel $(JOBS)
	"$(FULL_BUILD_DIR)/compositor/pedro-compositor"

host-check:
	@if test "$$(uname -s)" != Linux; then \
		echo "Pedro images require a native Linux host. Run make in Ubuntu/Linux, not macOS."; \
		exit 1; \
	fi

image-config: host-check
	$(call configure,$(BUILD_DIR),$(SUDO),-DPEDRO_BUILD_IMAGE=ON -DPEDRO_BUILD_COMPOSITOR=ON -DPEDRO_BUILD_INSTALLER=ON)

stage verify image: image-config
	$(SUDO) cmake --build "$(BUILD_DIR)" --target pedro-$@ --parallel $(JOBS)

clean:
	$(SUDO) rm -rf "$(BUILD_DIR)"
