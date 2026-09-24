cmake_minimum_required(VERSION 3.16)

project(services VERSION 0.1 LANGUAGES CXX)

# `services/` holds Pedro's systemd unit descriptors only. Executable
# implementations live in the corresponding Pedro component (see
# compositor/, gui/, ...). This module does NOT compile anything; it
# is purely responsible for shipping the unit files into the staged
# rootfs under /usr/lib/systemd/system.

# Install destinations are kept relative on purpose. The root CMakeLists
# drives the install prefix (build/staging/rootfs) so this component
# stays portable across staging layouts.
install(
        DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/
        DESTINATION usr/lib/systemd/system
        FILES_MATCHING PATTERN "*.service"
)
