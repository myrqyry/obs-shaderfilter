#!/usr/bin/env bash
# Render the actual standalone shader through the installed shaderfilter plugin.
# This uses a disposable headless libobs session and never touches OBS scenes.
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
module="${1:-$HOME/.config/obs-studio/plugins/obs-shaderfilter/bin/64bit/obs-shaderfilter.so}"
data="${2:-$HOME/.config/obs-studio/plugins/obs-shaderfilter/data}"
shader="$repo/data/examples/myrqyry/soft_register.shader"
test -r "$module" && test -r "$shader"
work="$(mktemp -d /tmp/shaderfilter-soft-register-XXXXXX)"
trap 'rm -rf "$work"' EXIT
inc="$(pkg-config --variable=includedir libobs)/obs"
libdir="$(pkg-config --variable=libdir libobs)"
g++ -std=gnu++20 -O2 -I"$inc" "$repo/tests/verify-soft-register.cpp" \
    -o "$work/verify" $(pkg-config --libs libobs) -Wl,-rpath,"$libdir"
xvfb-run -a -s '-screen 0 1280x720x24' \
    timeout 30 "$work/verify" "$module" "$data" "$shader"
