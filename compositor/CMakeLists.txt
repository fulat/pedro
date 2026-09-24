find_package(Qt6 6.5 REQUIRED COMPONENTS Quick WaylandCompositor)
find_package(PkgConfig REQUIRED)
pkg_check_modules(SYSTEMD REQUIRED IMPORTED_TARGET libsystemd)
qt_standard_project_setup(REQUIRES 6.5)
qt_add_executable(pedro_compositor main.cpp)
qt_add_qml_module(pedro_compositor
    URI PedroCompositor
    NO_IMPORT_SCAN
    QML_FILES Main.qml
)
target_link_libraries(pedro_compositor PRIVATE Qt6::Quick Qt6::WaylandCompositor PkgConfig::SYSTEMD)
set_target_properties(pedro_compositor PROPERTIES OUTPUT_NAME pedro-compositor)
install(TARGETS pedro_compositor RUNTIME DESTINATION usr/bin)
