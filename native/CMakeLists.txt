cmake_minimum_required(VERSION 3.21)
project(desktop-native LANGUAGES CXX)

find_package(Qt6 6.5 REQUIRED COMPONENTS Gui Qml)
qt_standard_project_setup(REQUIRES 6.5)

# The module lands in qml/Desktop/Native under the build directory: a qmldir,
# the plugin and its type information, copied out whole by the build script.
set(QT_QML_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml")

qt_add_qml_module(desktopnative
    URI Desktop.Native
    VERSION 1.0
    PLUGIN_TARGET desktopnative
    SOURCES IconThemeWatch.cpp IconThemeWatch.hpp
)
target_link_libraries(desktopnative PRIVATE Qt6::Gui Qt6::Qml)
