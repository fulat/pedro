cmake_minimum_required(VERSION 3.16)

project(pedro_gui VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

# The GUI is Pedro's graphical shell: a Qt 6 Quick / QML application
# that boots on top of the compositor. It is a regular Linux ELF
# executable (no .app bundle, no Win32 GUI subsystem).
find_package(Qt6 REQUIRED COMPONENTS Concurrent Quick Svg)

qt_standard_project_setup(REQUIRES 6.5)
qt_policy(SET QTP0004 NEW)

# Content imported from Figma to Qt or similar
if (EXISTS "${CMAKE_CURRENT_LIST_DIR}/importedcontent/CMakeLists.txt")
    add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/importedcontent)
endif()

qt_add_executable(pedro_gui
        main.cpp
        render/info.cpp
        render/info.hpp
)

qt_add_qml_module(pedro_gui
        URI gui
        # Pedro deploys dynamic Qt/QML modules as runtime packages. Import
        # scanning only tries to link unavailable static plugin targets on
        # distro Qt installations, so it is intentionally disabled here.
        NO_IMPORT_SCAN
        QML_FILES
        Main.qml
        RESOURCES
        qml/bar/Top.qml
        qml/bar/Player.qml
        qml/panel/Root.qml
        qml/glass/Surface.qml
        qml/system/View.qml
        qml/files/View.qml
        qml/about/View.qml
        qml/control/Center.qml
        qml/menu/Button.qml
        qml/status/Button.qml
        qml/metric/Card.qml
        qml/icon/Tinted.qml
        qml/quick/Tile.qml
        qml/slider/Tile.qml
        qml/toggle/Tile.qml
        qml/action/Tile.qml
        qml/media/Card.qml
        qml/media/Button.qml
        qml/wifi/View.qml
        qml/bluetooth/View.qml
        qml/bluetooth/Device.qml
        qml/sound/View.qml
        qml/option/Row.qml
        qml/toggle/Switch.qml
        qml/wifi/Network.qml
        qml/logic/theme.js
        qml/logic/clock.js
        qml/logic/pixel.js
        assets/icons/wifi.svg
        assets/icons/wifi-off.svg
        assets/icons/search.svg
        assets/icons/battery.svg
        assets/icons/moon.svg
        assets/icons/leaf.svg
        assets/icons/display.svg
        assets/icons/keyboard.svg
        assets/icons/camera.svg
        assets/icons/chevron.svg
        assets/icons/previous.svg
        assets/icons/next.svg
        assets/icons/pause.svg
        assets/icons/bluetooth.svg
        assets/icons/brightness.svg
        assets/icons/lock.svg
        assets/icons/power.svg
        assets/icons/restart.svg
        assets/icons/settings.svg
        assets/icons/speaker.svg
        assets/logo.png
        assets/artwork.svg
        assets/notch.svg
        assets/wallpaper.jpeg
        SOURCES
        backend.cpp
        backend.hpp
)

set_target_properties(pedro_gui PROPERTIES
        OUTPUT_NAME pedro-gui
)

target_link_libraries(pedro_gui
        PRIVATE
        Qt6::Concurrent
        Qt6::Quick
        Qt6::Svg
        pedro_papi
)

# A development-only convenience target. $<TARGET_FILE:...> resolves to the
# native executable on Linux and to the executable inside an app bundle on macOS.
add_custom_target(pedro-gui-run
        COMMAND ${CMAKE_COMMAND} -E env
                PEDRO_DEVELOPMENT_MODE=1
                PEDRO_QML_DIR=${CMAKE_CURRENT_SOURCE_DIR}
                $<TARGET_FILE:pedro_gui>
        DEPENDS pedro_gui
        USES_TERMINAL
)

# Install destinations are kept relative on purpose. The root CMakeLists
# drives the install prefix (build/staging/rootfs) so this component
# stays portable across staging layouts.
install(
        TARGETS pedro_gui
        RUNTIME DESTINATION usr/bin
)
