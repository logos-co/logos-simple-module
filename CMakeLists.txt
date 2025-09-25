cmake_minimum_required(VERSION 3.16)

project(LogosSimpleModule LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Core RemoteObjects)
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Core RemoteObjects)

set(LOGOS_VENDOR_BINARY_DIR "${CMAKE_BINARY_DIR}/vendor")

add_subdirectory(vendor/LogosCore "${LOGOS_VENDOR_BINARY_DIR}/LogosCore")

if(TARGET logos_core AND NOT TARGET Logos::Core)
    add_library(Logos::Core ALIAS logos_core)
endif()

if(TARGET logos_sdk AND NOT TARGET Logos::SDK)
    add_library(Logos::SDK ALIAS logos_sdk)
endif()

set(LOGOS_CPP_GENERATOR_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/vendor/LogosCppGenerator")
if(EXISTS "${LOGOS_CPP_GENERATOR_SOURCE_DIR}/CMakeLists.txt")
    add_subdirectory("${LOGOS_CPP_GENERATOR_SOURCE_DIR}" "${LOGOS_VENDOR_BINARY_DIR}/LogosCppGenerator")
endif()

set(PLUGINS_OUTPUT_DIR "${CMAKE_BINARY_DIR}/modules")
file(MAKE_DIRECTORY "${PLUGINS_OUTPUT_DIR}")

set(METADATA_JSON "${CMAKE_CURRENT_SOURCE_DIR}/metadata.json")

set(LOGOS_CPP_GENERATOR_HINTS
    "${LOGOS_VENDOR_BINARY_DIR}/LogosCppGenerator/bin"
    "${CMAKE_CURRENT_BINARY_DIR}/vendor/LogosCppGenerator/bin"
    "${CMAKE_CURRENT_BINARY_DIR}/vendor/LogosCppGenerator/build/bin"
    "${LOGOS_CPP_GENERATOR_SOURCE_DIR}/build/bin"
    "${CMAKE_CURRENT_SOURCE_DIR}/vendor/LogosCppGenerator/bin"
    "${CMAKE_CURRENT_SOURCE_DIR}/vendor/SDK/cpp-generator/build/bin"
    "${CMAKE_CURRENT_SOURCE_DIR}/vendor/SDK/cpp-generator/bin"
    "${CMAKE_CURRENT_SOURCE_DIR}/../logos-core-poc/build/cpp-generator/bin"
)

find_program(LOGOS_CPP_GENERATOR_EXECUTABLE
    NAMES logos-cpp-generator
    PATHS ${LOGOS_CPP_GENERATOR_HINTS}
    NO_DEFAULT_PATH
)

if(NOT LOGOS_CPP_GENERATOR_EXECUTABLE)
    find_program(LOGOS_CPP_GENERATOR_EXECUTABLE NAMES logos-cpp-generator)
endif()

if(TARGET logos-cpp-generator)
    set(LOGOS_CPP_GENERATOR_EXECUTABLE $<TARGET_FILE:logos-cpp-generator>)
endif()

if(LOGOS_CPP_GENERATOR_EXECUTABLE STREQUAL "LOGOS_CPP_GENERATOR_EXECUTABLE-NOTFOUND")
    unset(LOGOS_CPP_GENERATOR_EXECUTABLE)
endif()

set(LOGOS_CPP_GENERATOR_SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/cmake/run_generator.cmake")

add_custom_target(run_cpp_generator_simple
    COMMAND ${CMAKE_COMMAND}
        "-DGENERATOR=${LOGOS_CPP_GENERATOR_EXECUTABLE}"
        "-DMETADATA=${METADATA_JSON}"
        "-DOUTPUT_DIR=${PLUGINS_OUTPUT_DIR}"
        "-DWORKING_DIRECTORY=${CMAKE_BINARY_DIR}"
        -P "${LOGOS_CPP_GENERATOR_SCRIPT}"
    WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
    COMMENT "Running logos-cpp-generator on ${METADATA_JSON} with module-dir ${PLUGINS_OUTPUT_DIR}"
    VERBATIM
)

set(PLUGIN_SOURCES
    simple_module_interface.h
    simple_module_plugin.cpp
    simple_module_plugin.h
)

add_library(simple_module_plugin SHARED ${PLUGIN_SOURCES})

set_target_properties(simple_module_plugin PROPERTIES
    PREFIX ""
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/modules"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/modules"
    BUILD_WITH_INSTALL_RPATH TRUE
    SKIP_BUILD_RPATH FALSE
)

add_dependencies(simple_module_plugin run_cpp_generator_simple)

target_link_libraries(simple_module_plugin PRIVATE
    Qt${QT_VERSION_MAJOR}::Core
    Qt${QT_VERSION_MAJOR}::RemoteObjects
    Logos::SDK
    Logos::Core
)

target_include_directories(simple_module_plugin PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_BINARY_DIR}/SDK/cpp/generated
    ${CMAKE_CURRENT_SOURCE_DIR}/vendor/LogosCore
)

if(APPLE)
    set_target_properties(simple_module_plugin PROPERTIES
        INSTALL_RPATH "@loader_path"
        INSTALL_NAME_DIR "@rpath"
        BUILD_WITH_INSTALL_NAME_DIR TRUE
    )

    add_custom_command(TARGET simple_module_plugin POST_BUILD
        COMMAND install_name_tool -id "@rpath/simple_module_plugin.dylib" $<TARGET_FILE:simple_module_plugin>
        COMMENT "Updating library paths for macOS"
    )
else()
    set_target_properties(simple_module_plugin PROPERTIES
        INSTALL_RPATH "$ORIGIN"
        INSTALL_RPATH_USE_LINK_PATH FALSE
    )
endif()
