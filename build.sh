#!/bin/bash

# Build script for obs-shaderfilter-plus-next
# Supports both in-tree and standalone builds

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"

# Parse command line arguments
BUILD_TYPE="Release"
CLEAN=false
INSTALL=false
OBS_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--debug)
            BUILD_TYPE="Debug"
            shift
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -i|--install)
            INSTALL=true
            shift
            ;;
        --obs-dir)
            OBS_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [-d|--debug] [-c|--clean] [-i|--install] [--obs-dir PATH]"
            exit 1
            ;;
    esac
done

# Clean if requested
if [ "$CLEAN" = true ]; then
    echo "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
fi

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure
echo "Configuring..."
CMAKE_ARGS=()
CMAKE_ARGS+=("-DCMAKE_BUILD_TYPE=$BUILD_TYPE")

if [ -n "$OBS_DIR" ]; then
    CMAKE_ARGS+=("-DOBS_DIR=$OBS_DIR")
fi

cmake .. "${CMAKE_ARGS[@]}"

# Build
echo "Building..."
cmake --build . --config "$BUILD_TYPE" -j$(nproc)

# Install if requested
if [ "$INSTALL" = true ]; then
    echo "Installing..."
    sudo cmake --install . --config "$BUILD_TYPE"
fi

echo "Build complete!"