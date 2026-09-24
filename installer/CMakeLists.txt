cmake_minimum_required(VERSION 3.16)

project(pedro_installer VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

# The installer is a Qt 6 Quick / QML application used to bootstrap
# Pedro onto target hardware. It is a regular Linux ELF executable
# (no .app bundle, no Win32 GUI subsystem).
find_package(Qt6 REQUIRED COMPONENTS Quick)

qt_standard_project_setup(REQUIRES 6.5)


qt_add_executable(pedro_installer
    main.cpp
)

qt_add_qml_module(pedro_installer
    URI pedro_installer
    NO_IMPORT_SCAN
    QML_FILES
        Main.qml
)

target_link_libraries(pedro_installer
    PRIVATE Qt6::Quick
)

set_target_properties(pedro_installer PROPERTIES
    OUTPUT_NAME pedro-installer
)

# Install destinations are kept relative on purpose. The root CMakeLists
# drives the install prefix (build/staging/rootfs) so this component
# stays portable across staging layouts.
install(TARGETS pedro_installer
    RUNTIME DESTINATION usr/bin
)
