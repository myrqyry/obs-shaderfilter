#!/usr/bin/env bash
set -euo pipefail
directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if ! command -v pkg-config >/dev/null || ! pkg-config --exists libobs; then
    echo "Missing pkg-config or libobs development package" >&2
    exit 2
fi
include="$(pkg-config --variable=includedir libobs)"
c++ -std=c++17 -O2 -I"$include/obs" "$directory/verify_psx.cpp" \
    $(pkg-config --libs libobs) -o "$work/verify_psx"

inputs=(
    "$directory/psx_dither_quantize.shader"
    "$directory/psx_color_grade.shader"
    "$directory/psx_instability.shader"
    "$directory/psx_analog_hybrid.shader"
)
if [[ -n "${DISPLAY:-}" ]]; then
    "$work/verify_psx" "${inputs[@]}"
elif command -v xvfb-run >/dev/null; then
    xvfb-run -a -s "-screen 0 800x600x24" "$work/verify_psx" "${inputs[@]}"
else
    echo "An active X display or xvfb-run is required for OpenGL render verification" >&2
    exit 2
fi
