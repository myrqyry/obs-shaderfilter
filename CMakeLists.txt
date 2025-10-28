cmake_minimum_required(VERSION 3.16)

project(obs-shaderfilter-plus-next VERSION 1.0.0)
set(PROJECT_FULL_NAME "OBS ShaderFilter Plus Next")

# ===== PLUGIN METADATA =====
set(PLUGIN_AUTHOR "myrqyry")
set(PLUGIN_GIT obs-shaderfilter-plus-next)
set(MACOS_BUNDLEID "com.myrqyry.obs-shaderfilter-plus-next")
set(LINUX_MAINTAINER_EMAIL "your.actual.email@example.com")

# ===== PLATFORM DETECTION =====
if(UNIX AND NOT APPLE)
    set(LINUX TRUE)
    set(OS_LINUX TRUE)
endif()

# ===== BUILD OPTIONS =====
option(ENABLE_FRONTEND_API "Use obs-frontend-api for advanced features" ON)
option(ENABLE_QT "Enable Qt-based UI features" OFF)
option(ENABLE_TSAN "Build with ThreadSanitizer" OFF)

if(ENABLE_TSAN)
  if (CMAKE_CXX_COMPILER_ID MATCHES "Clang|AppleClang|GNU")
    message(STATUS "Enabling ThreadSanitizer")
    add_compile_options(-fsanitize=thread -g -O1 -fno-omit-frame-pointer)
    add_link_options(-fsanitize=thread)
  endif()
endif()

# ===== LANGUAGE SETTINGS =====
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# ===== OBS LIBRARY DETECTION =====
# Support both in-tree and standalone builds

# Check if building as part of OBS
if(EXISTS "${CMAKE_SOURCE_DIR}/libobs")
    set(IN_OBS_BUILD TRUE)
    message(STATUS "Building as part of OBS Studio")
else()
    set(IN_OBS_BUILD FALSE)
    message(STATUS "Building as standalone plugin")
endif()

if(IN_OBS_BUILD)
    # In-tree build (inside OBS source)
    find_package(libobs REQUIRED)
    if(ENABLE_FRONTEND_API)
        find_package(obs-frontend-api REQUIRED)
    endif()
else()
    # Standalone build
    if(LINUX)
        # Use pkg-config on Linux for simplicity and robustness
        find_package(PkgConfig REQUIRED)
        pkg_check_modules(OBS REQUIRED libobs)
        if(NOT OBS_FOUND)
            message(FATAL_ERROR "OBS Studio development files (libobs-dev) not found.")
        endif()

        set(LibOBS_INCLUDE_DIR ${OBS_INCLUDE_DIRS})
        set(LibOBS_LIBRARY ${OBS_LIBRARIES})

        if(ENABLE_FRONTEND_API)
            pkg_check_modules(OBS_FRONTEND QUIET obs-frontend-api)
            if(OBS_FRONTEND_FOUND)
                list(APPEND LibOBS_LIBRARY ${OBS_FRONTEND_LIBRARIES})
            endif()
        endif()
        message(STATUS "Found OBS (via pkg-config) Includes: ${LibOBS_INCLUDE_DIR}")
        message(STATUS "Found OBS (via pkg-config) Libraries: ${LibOBS_LIBRARY}")
    else() # For Windows and macOS
        # Try to find OBS in standard locations
        if(NOT OBS_DIR)
            if(WIN32)
                set(OBS_SEARCH_PATHS
                    "C:/Program Files/obs-studio"
                    "C:/Program Files (x86)/obs-studio"
                    "$ENV{ProgramFiles}/obs-studio"
                )
            elseif(APPLE)
                set(OBS_SEARCH_PATHS
                    "/Applications/OBS.app/Contents/Resources"
                    "/usr/local/opt/obs"
                )
            endif()

            foreach(SEARCH_PATH ${OBS_SEARCH_PATHS})
                if(EXISTS "${SEARCH_PATH}/include/obs-module.h" OR
                   EXISTS "${SEARCH_PATH}/include/obs/obs-module.h")
                    set(OBS_DIR ${SEARCH_PATH})
                    message(STATUS "Found OBS at: ${OBS_DIR}")
                    break()
                endif()
            endforeach()
        endif()

        # Set include and library paths
        if(WIN32)
            if(CMAKE_SIZEOF_VOID_P EQUAL 8)
                set(OBS_ARCH_DIR "64bit")
            else()
                set(OBS_ARCH_DIR "32bit")
            endif()

            set(LibOBS_INCLUDE_DIR "${OBS_DIR}/include")
            set(LibOBS_LIBRARY "${OBS_DIR}/bin/${OBS_ARCH_DIR}/obs.lib")
            if(ENABLE_FRONTEND_API)
                set(LibOBS_Frontend_LIBRARY "${OBS_DIR}/bin/${OBS_ARCH_DIR}/obs-frontend-api.lib")
            endif()
        elseif(APPLE)
            set(LibOBS_INCLUDE_DIR "${OBS_DIR}/include")
            set(LibOBS_LIBRARY "${OBS_DIR}/bin/libobs.dylib")
            if(ENABLE_FRONTEND_API)
                set(LibOBS_Frontend_LIBRARY "${OBS_DIR}/bin/libobs-frontend-api.dylib")
            endif()
        endif()

        # Verify we found everything
        if(NOT LibOBS_INCLUDE_DIR OR NOT EXISTS "${LibOBS_INCLUDE_DIR}")
            message(FATAL_ERROR
                "Could not find OBS Studio headers.\n"
                "Please install OBS Studio or set OBS_DIR to your OBS installation path.\n"
                "Current OBS_DIR: ${OBS_DIR}\n"
                "Looking for: obs-module.h"
            )
        endif()

        if(NOT LibOBS_LIBRARY OR NOT EXISTS "${LibOBS_LIBRARY}")
            message(FATAL_ERROR
                "Could not find OBS Studio library.\n"
                "Please install OBS Studio development files or set OBS_DIR correctly.\n"
                "Looking for: libobs"
            )
        endif()

        message(STATUS "OBS Include Dir: ${LibOBS_INCLUDE_DIR}")
        message(STATUS "OBS Library: ${LibOBS_LIBRARY}")
    endif()
endif()

# ===== FFTW LIBRARY DETECTION (for Audio Reactivity) =====
# We need the single-precision (float) version of FFTW3
find_package(FFTW3F QUIET HINTS /usr/local /usr)
if(FFTW3F_FOUND)
    message(STATUS "Found FFTW3 (single-precision), enabling full audio reactivity.")
else()
    message(WARNING "FFTW3 (single-precision) not found. Audio reactivity will use simulated data.")
endif()

# Fallback: if the CMake package wasn't found, try to locate fftw3 header and single-precision
# library manually (common on many distros where a FindFFTW3F.cmake may not be available).
if(NOT FFTW3F_FOUND)
    find_path(FFTW3F_INCLUDE_DIR NAMES fftw3.h PATHS /usr/include /usr/local/include NO_DEFAULT_PATH)
    find_library(FFTW3F_LIBRARY NAMES fftw3f fftw3f.so fftw3f.so.3 PATHS /usr/lib /usr/lib/x86_64-linux-gnu /lib /lib/x86_64-linux-gnu /usr/local/lib NO_DEFAULT_PATH)

    if(FFTW3F_INCLUDE_DIR AND FFTW3F_LIBRARY)
        message(STATUS "Found FFTW3 (single-precision) via fallback detection.")
        set(FFTW3F_FOUND TRUE)
        # Provide variables for consistency with find_package
        set(FFTW3F_INCLUDE_DIRS ${FFTW3F_INCLUDE_DIR})
        set(FFTW3F_LIBRARIES ${FFTW3F_LIBRARY})
    endif()
endif()

# ===== SOURCE FILES =====
set(PLUGIN_SOURCES
    src/obs-shaderfilter-plus-next.cpp
    src/shader_filter.cpp
    src/shader_filter_properties.cpp
    src/hot_reload.cpp
    src/multi_input.cpp
    # Use audio_reactive.cpp when FFTW is available, otherwise build a stub
)

if(FFTW3F_FOUND)
    list(APPEND PLUGIN_SOURCES src/audio_reactive.cpp)
else()
    list(APPEND PLUGIN_SOURCES src/audio_reactive_stub.cpp)
endif()

set(PLUGIN_HEADERS
    include/shader_filter.hpp
    include/hot_reload.hpp
    include/multi_input.hpp
    include/audio_reactive.hpp
)

# ===== BUILD TARGET =====
if(ENABLE_TSAN)
    set(PLUGIN_LIB_TYPE SHARED)
else()
    set(PLUGIN_LIB_TYPE MODULE)
endif()

add_library(${PROJECT_NAME} ${PLUGIN_LIB_TYPE}
    ${PLUGIN_SOURCES}
    ${PLUGIN_HEADERS}
)

if(ENABLE_TSAN)
    target_compile_definitions(${PROJECT_NAME} PRIVATE TEST_HARNESS_BUILD)
endif()

# ===== TESTING =====
if(ENABLE_TSAN)
    add_executable(test_hot_reload tests/test_hot_reload.cpp)
    target_include_directories(test_hot_reload PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
    target_link_libraries(test_hot_reload PRIVATE ${PROJECT_NAME})
    target_compile_definitions(test_hot_reload PRIVATE TEST_HARNESS_BUILD)
    set_target_properties(test_hot_reload PROPERTIES CXX_STANDARD 20)
endif()

# ===== INCLUDE DIRECTORIES =====
target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

# Ensure our local include directory is searched before system includes so
# our shim headers (obs/.. shims) are picked up when present.
target_include_directories(${PROJECT_NAME} BEFORE PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)

if(IN_OBS_BUILD)
    target_include_directories(${PROJECT_NAME} PRIVATE
        ${LibOBS_INCLUDE_DIRS}
    )
else()
    target_include_directories(${PROJECT_NAME} PRIVATE
        ${LibOBS_INCLUDE_DIR}
    )
endif()

# When building standalone on Linux, make sure the system OBS include dir is searched
# before any /usr/local paths to avoid picking older/conflicting headers.
if(NOT IN_OBS_BUILD AND LINUX)
    if(EXISTS "/usr/include/obs")
        target_include_directories(${PROJECT_NAME} BEFORE PRIVATE /usr/include/obs)
    endif()
endif()

target_include_directories(${PROJECT_NAME} PRIVATE
    ${LibOBS_INCLUDE_DIR}
)

# ===== LINK LIBRARIES =====
if(FFTW3F_FOUND)
    target_compile_definitions(${PROJECT_NAME} PRIVATE USE_FFTW)
    # If a proper imported target exists (from find_package), use it. Otherwise
    # fall back to the library path discovered above.
    if(TARGET FFTW3F::fftw3f)
        target_link_libraries(${PROJECT_NAME} PRIVATE FFTW3F::fftw3f)
    elseif(DEFINED FFTW3F_LIBRARIES)
        if(DEFINED FFTW3F_INCLUDE_DIRS)
            target_include_directories(${PROJECT_NAME} PRIVATE ${FFTW3F_INCLUDE_DIRS})
        elseif(DEFINED FFTW3F_INCLUDE_DIR)
            target_include_directories(${PROJECT_NAME} PRIVATE ${FFTW3F_INCLUDE_DIR})
        endif()
        target_link_libraries(${PROJECT_NAME} PRIVATE ${FFTW3F_LIBRARIES})
    elseif(DEFINED FFTW3F_LIBRARY)
        if(DEFINED FFTW3F_INCLUDE_DIR)
            target_include_directories(${PROJECT_NAME} PRIVATE ${FFTW3F_INCLUDE_DIR})
        endif()
        target_link_libraries(${PROJECT_NAME} PRIVATE ${FFTW3F_LIBRARY})
    else()
        message(WARNING "FFTW3 was marked found but no usable target or library variable is set.")
    endif()
endif()

if(IN_OBS_BUILD)
    target_link_libraries(${PROJECT_NAME} PRIVATE
        OBS::libobs
    )
    if(ENABLE_FRONTEND_API)
        target_link_libraries(${PROJECT_NAME} PRIVATE
            OBS::obs-frontend-api
        )
    endif()
else()
    target_link_libraries(${PROJECT_NAME} PRIVATE
        ${LibOBS_LIBRARY}
    )
    if(ENABLE_FRONTEND_API AND LibOBS_Frontend_LIBRARY)
        target_link_libraries(${PROJECT_NAME} PRIVATE
            ${LibOBS_Frontend_LIBRARY}
        )
    endif()
endif()

# ===== COMPILER FLAGS =====
if(MSVC)
	set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
	add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
    target_compile_options(${PROJECT_NAME} PRIVATE
        /W4
        /WX-
        /permissive-
    )
elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(${PROJECT_NAME} PRIVATE
        -Wall
        -Wextra
        -Wno-unused-parameter
        -Wno-unused-function
        -fPIC
    )
endif()

# ===== PLATFORM-SPECIFIC SETTINGS =====
if(LINUX)
    # Linux: Remove lib prefix from plugin
    set_target_properties(${PROJECT_NAME} PROPERTIES
        PREFIX ""
        SUFFIX ".so"
    )

    # Add pthread for threading (hot reload)
    target_link_libraries(${PROJECT_NAME} PRIVATE pthread stdc++fs)

elseif(WIN32)
    set_target_properties(${PROJECT_NAME} PROPERTIES
        SUFFIX ".dll"
    )

elseif(APPLE)
    set_target_properties(${PROJECT_NAME} PROPERTIES
        PREFIX ""
        SUFFIX ".dylib"
        MACOSX_BUNDLE_GUI_IDENTIFIER "${MACOS_BUNDLEID}"
    )

    find_library(COREFOUNDATION_LIBRARY CoreFoundation REQUIRED)
    target_link_libraries(${PROJECT_NAME} PRIVATE ${COREFOUNDATION_LIBRARY})
endif()

# ===== INSTALLATION =====
if(IN_OBS_BUILD)
    # Use OBS's built-in installation
    setup_plugin_target(${PROJECT_NAME})
else()
    # Standalone installation paths compatible with OBS 32.0 Plugin Manager
    if(LINUX)
        set(PLUGIN_INSTALL_DIR "lib/obs-plugins")
        set(DATA_INSTALL_DIR "share/obs/obs-plugins/${PROJECT_NAME}")
    elseif(WIN32)
        # For plugin manager compatibility, prefer the structured approach
        if(CMAKE_SIZEOF_VOID_P EQUAL 8)
            set(PLUGIN_INSTALL_DIR "obs-plugins/64bit")
        else()
            set(PLUGIN_INSTALL_DIR "obs-plugins/32bit")
        endif()
        set(DATA_INSTALL_DIR "data/obs-plugins/${PROJECT_NAME}")
    elseif(APPLE)
        set(PLUGIN_INSTALL_DIR "obs-plugins")
        set(DATA_INSTALL_DIR "data/obs-plugins/${PROJECT_NAME}")
    endif()

    # Install plugin library
    install(TARGETS ${PROJECT_NAME}
        LIBRARY DESTINATION ${PLUGIN_INSTALL_DIR}
        RUNTIME DESTINATION ${PLUGIN_INSTALL_DIR}
    )

    # Install data files with correct structure
    install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/data/
        DESTINATION ${DATA_INSTALL_DIR}
        FILES_MATCHING
            PATTERN "*.effect"
            PATTERN "*.shader"
            PATTERN "*.png"
            PATTERN "*.jpg"
    )

    # Install locale files - this is CRITICAL for plugin manager recognition
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/data/locale/")
        install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/data/locale/
            DESTINATION ${DATA_INSTALL_DIR}/locale
            FILES_MATCHING PATTERN "*.ini"
        )
    endif()
endif()

# ===== BUILD INFO =====
message(STATUS "")
message(STATUS "OBS ShaderFilter Plus Next Configuration:")
message(STATUS "  Version: ${PROJECT_VERSION}")
message(STATUS "  Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  Platform: ${CMAKE_SYSTEM_NAME}")
message(STATUS "  In-Tree Build: ${IN_OBS_BUILD}")
message(STATUS "  Frontend API: ${ENABLE_FRONTEND_API}")
message(STATUS "")