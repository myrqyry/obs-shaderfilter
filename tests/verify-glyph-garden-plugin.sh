#!/usr/bin/env bash
# Verify actual OBS ShaderFilter plugin's file loader, properties, and pixel output.
# The selected shader may be anywhere on disk; no direct repository include expansion.
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
module="${1:-$HOME/.config/obs-studio/plugins/obs-shaderfilter/bin/64bit/obs-shaderfilter.so}"
data="${2:-$HOME/.config/obs-studio/plugins/obs-shaderfilter/data}"
shader="${3:-$repo/data/examples/myrqyry/glyph-garden.shader}"
test -r "$module" && test -r "$shader"
work="$(mktemp -d /tmp/shaderfilter-garden-XXXXXX)"
trap 'rm -rf "$work"' EXIT
inc="$(pkg-config --variable=includedir libobs)/obs"
libdir="$(pkg-config --variable=libdir libobs)"
g++ -std=gnu++20 -O2 -I"$inc" "$repo/tests/verify-glyph-garden-plugin.cpp" -o "$work/verify" $(pkg-config --libs libobs) -Wl,-rpath,"$libdir"
xvfb-run -a -s '-screen 0 1280x720x24' timeout 30 "$work/verify" "$module" "$data" "$shader"
