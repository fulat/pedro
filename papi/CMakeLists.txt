cmake_minimum_required(VERSION 3.16)

project(pedro_papi VERSION 0.1 LANGUAGES CXX)

find_package(Qt6 REQUIRED COMPONENTS DBus)

set(PEDRO_PAPI_BLUETOOTH_HEADERS
        bluetooth/device.hpp
        bluetooth/manager.hpp
        bluetooth/snapshot.hpp
)

set(PEDRO_PAPI_WIFI_HEADERS
        network/wifi/access.hpp
        network/wifi/manager.hpp
        network/wifi/snapshot.hpp
)

set(PEDRO_PAPI_GENERATED_INCLUDE "${CMAKE_CURRENT_BINARY_DIR}/include")
file(MAKE_DIRECTORY "${PEDRO_PAPI_GENERATED_INCLUDE}/pedro/papi/bluetooth")
file(MAKE_DIRECTORY "${PEDRO_PAPI_GENERATED_INCLUDE}/pedro/papi/network/wifi")

foreach(header IN LISTS PEDRO_PAPI_BLUETOOTH_HEADERS)
    get_filename_component(name "${header}" NAME)
    configure_file(
            "${CMAKE_CURRENT_SOURCE_DIR}/${header}"
            "${PEDRO_PAPI_GENERATED_INCLUDE}/pedro/papi/bluetooth/${name}"
            COPYONLY
    )
endforeach()

foreach(header IN LISTS PEDRO_PAPI_WIFI_HEADERS)
    get_filename_component(name "${header}" NAME)
    configure_file(
            "${CMAKE_CURRENT_SOURCE_DIR}/${header}"
            "${PEDRO_PAPI_GENERATED_INCLUDE}/pedro/papi/network/wifi/${name}"
            COPYONLY
    )
endforeach()

# PAPI is Pedro's system API. Its public surface is independent of Qt so the
# GUI, other Pedro components, and future applications can all consume it.
add_library(pedro_papi STATIC
        bluetooth/manager.cpp
        filesystem/filesystem.cpp
        network/wifi/manager.cpp
        system/system.cpp
)

target_include_directories(pedro_papi
        PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
        $<BUILD_INTERFACE:${PEDRO_PAPI_GENERATED_INCLUDE}>
        $<INSTALL_INTERFACE:usr/include>
)

target_compile_features(pedro_papi PUBLIC cxx_std_17)

target_link_libraries(pedro_papi PRIVATE Qt6::DBus)

install(TARGETS pedro_papi ARCHIVE DESTINATION usr/lib)
install(
        DIRECTORY include/
        DESTINATION usr/include
)
install(
        FILES ${PEDRO_PAPI_BLUETOOTH_HEADERS}
        DESTINATION usr/include/pedro/papi/bluetooth
)
install(
        FILES ${PEDRO_PAPI_WIFI_HEADERS}
        DESTINATION usr/include/pedro/papi/network/wifi
)
install(FILES papi.h DESTINATION usr/include/pedro/papi)
