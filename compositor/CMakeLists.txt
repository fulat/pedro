cmake_minimum_required(VERSION 3.16)

project(compositor VERSION 0.1 LANGUAGES CXX)

find_package(Qt6 REQUIRED COMPONENTS Gui)

qt_add_executable(compositor
        main.cpp
)

target_link_libraries(compositor
        PRIVATE
        Qt6::Gui
)

install(
        TARGETS compositor
        RUNTIME DESTINATION bin
)