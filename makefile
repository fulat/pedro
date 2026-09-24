# Thin developer interface. CMake owns the build and image pipeline.
# The image pipeline stages Linux ownership and therefore runs through sudo.
BUILD_DIR := build
CACHE_FILE := $(BUILD_DIR)/CMakeCache.txt
DEV_BUILD_DIR := $(BUILD_DIR)/dev
DEV_CACHE_FILE := $(DEV_BUILD_DIR)/CMakeCache.txt
GUI_EXECUTABLE := $(DEV_BUILD_DIR)/gui/pedro-gui
COMPOSITOR_BUILD_DIR := $(BUILD_DIR)/compositor

ifeq ($(shell id -u),0)
SUDO :=
else
SUDO := sudo
endif

DEV_CMAKE_ARGS ?=

.DEFAULT_GOAL := image

.PHONY: help host-check configure dev-configure gui-configure gui-build gui GUI dev start qml diagnose compositor build stage verify image clean
help:
	@echo "make            Build build/images/pedro.img"
	@echo "make start      Incrementally build and launch the Ubuntu-native GUI"
	@echo "make dev        Same as make start"
	@echo "make GUI        Same as make start"
	@echo "make gui-build  Build only PAPI and the GUI in build/dev"
	@echo "make gui        Same as make start"
	@echo "make qml        Relaunch the existing binary with QML loaded from source"
	@echo "make diagnose   Launch the GUI and print display/rendering diagnostics"
	@echo "make compositor | build | stage | verify | image | clean"
host-check:
	@if test "$$(uname -s)" != Linux; then \
		echo "Pedro images require a native Linux host. Run make in Ubuntu/Linux, not macOS."; \
		exit 1; \
	fi

configure: host-check
	@if test -f "$(CACHE_FILE)" && ! grep -Fqx "CMAKE_HOME_DIRECTORY:INTERNAL=$(CURDIR)" "$(CACHE_FILE)"; then \
		echo "Removing stale build cache created for a different source path."; \
		$(SUDO) rm -rf "$(BUILD_DIR)"; \
	fi
	$(SUDO) cmake -S . -B "$(BUILD_DIR)" -G Ninja -DPEDRO_BUILD_IMAGE=ON

dev-configure:
	@if test -f "$(DEV_CACHE_FILE)" && ! grep -Fqx "CMAKE_HOME_DIRECTORY:INTERNAL=$(CURDIR)" "$(DEV_CACHE_FILE)"; then \
		echo "build/dev belongs to a different source path; remove it before continuing."; \
		exit 1; \
	fi
	cmake -S . -B "$(DEV_BUILD_DIR)" -G Ninja \
		-DPEDRO_BUILD_IMAGE=OFF \
		-DPEDRO_BUILD_COMPOSITOR=OFF \
		-DPEDRO_BUILD_INSTALLER=OFF \
		$(DEV_CMAKE_ARGS)

gui-configure: dev-configure

gui-build: dev-configure
	cmake --build "$(DEV_BUILD_DIR)" --target pedro_gui --parallel 4

gui: gui-build
	cmake --build "$(DEV_BUILD_DIR)" --target pedro-gui-run

dev: gui

start: gui

GUI: gui

qml:
	@test -x "$(GUI_EXECUTABLE)" || { echo "Run 'make gui-build' once before 'make qml'."; exit 1; }
	PEDRO_DEVELOPMENT_MODE=1 PEDRO_QML_DIR="$(CURDIR)/gui" "$(GUI_EXECUTABLE)"

diagnose: gui-build
	PEDRO_DEVELOPMENT_MODE=1 PEDRO_RENDER_DIAGNOSTICS=1 QSG_INFO=1 \
		PEDRO_QML_DIR="$(CURDIR)/gui" "$(GUI_EXECUTABLE)"

compositor:
	cmake -S . -B "$(COMPOSITOR_BUILD_DIR)" -G Ninja \
		-DPEDRO_BUILD_IMAGE=OFF -DPEDRO_BUILD_COMPOSITOR=ON -DPEDRO_BUILD_INSTALLER=OFF
	cmake --build "$(COMPOSITOR_BUILD_DIR)" --target pedro_compositor
	"$(COMPOSITOR_BUILD_DIR)/compositor/pedro-compositor"
build: configure
	$(SUDO) cmake --build "$(BUILD_DIR)" --parallel 4

stage: configure
	$(SUDO) cmake --build "$(BUILD_DIR)" --target pedro-stage --parallel 4

verify: configure
	$(SUDO) cmake --build "$(BUILD_DIR)" --target pedro-verify --parallel 4

image: configure
	$(SUDO) cmake --build "$(BUILD_DIR)" --target pedro-image --parallel 4

clean:
	$(SUDO) rm -rf "$(BUILD_DIR)"
