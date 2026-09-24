cmake_minimum_required(VERSION 3.22)
project(pedro VERSION 0.1 LANGUAGES CXX)

# Reject unsafe destinations before project() generates compiler probes.
file(REAL_PATH "${CMAKE_SOURCE_DIR}" _source)
file(REAL_PATH "${CMAKE_BINARY_DIR}" _binary)

set(_allowed "${_source}/build")
cmake_path(IS_PREFIX _allowed "${_binary}" NORMALIZE _inside_build)

if(NOT _inside_build)
    message(FATAL_ERROR "All generated output must be inside the repository build/ directory.")
endif()


set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(PEDRO_BUILD_IMAGE "Enable the native Linux OS pipeline" ON)
option(PEDRO_BUILD_COMPOSITOR "Build the Pedro Wayland compositor" ON)
option(PEDRO_BUILD_INSTALLER "Build the Pedro installer" ON)

if(PEDRO_BUILD_IMAGE AND (NOT PEDRO_BUILD_COMPOSITOR OR NOT PEDRO_BUILD_INSTALLER))
    message(FATAL_ERROR "The image pipeline requires the compositor and installer components.")
endif()

if(PEDRO_BUILD_IMAGE)
    if(NOT CMAKE_SYSTEM_NAME STREQUAL "Linux" OR CMAKE_CROSSCOMPILING)
        message(FATAL_ERROR "Pedro images require native Linux. Use -DPEDRO_BUILD_IMAGE=OFF for GUI development only.")
    endif()

    if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
        set(PEDRO_ARCH aarch64)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64)$")
        set(PEDRO_ARCH x86_64)
    else()
        message(FATAL_ERROR "Unsupported architecture: ${CMAKE_SYSTEM_PROCESSOR}")
    endif()

    find_package(Python3 REQUIRED COMPONENTS Interpreter)
    configure_file(pedro_pipeline.py cmake/pedro_pipeline.py COPYONLY)

    execute_process(COMMAND "${Python3_EXECUTABLE}"
        "${CMAKE_BINARY_DIR}/cmake/pedro_pipeline.py" check
        "${CMAKE_SOURCE_DIR}" "${CMAKE_BINARY_DIR}" "${PEDRO_ARCH}"
        COMMAND_ERROR_IS_FATAL ANY)
endif()

add_subdirectory(papi)
add_subdirectory(services)

if(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND PEDRO_BUILD_COMPOSITOR)
    add_subdirectory(compositor)
endif()

add_subdirectory(gui)
if(PEDRO_BUILD_INSTALLER)
    add_subdirectory(installer)
endif()

if(PEDRO_BUILD_IMAGE)
    foreach(step stage verify image)
        add_custom_target(pedro-${step}
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_BINARY_DIR}/cmake/pedro_pipeline.py"
                ${step} "${CMAKE_SOURCE_DIR}" "${CMAKE_BINARY_DIR}" "${PEDRO_ARCH}"
            USES_TERMINAL VERBATIM)
    endforeach()

    add_dependencies(pedro-stage pedro_compositor pedro_gui pedro_installer)
    add_dependencies(pedro-verify pedro-stage)
    add_dependencies(pedro-image pedro-verify)
    add_custom_target(pedro-all ALL DEPENDS pedro-image)

endif()
