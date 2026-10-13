#!/usr/bin/env bash
# Reproducible standalone RetroCapture .glslp GPU graph proof, NOT OBS plugin integration.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REV=af76c6cb30688704c05ae2fef4feffb4ab3ce777
REPOSITORY="${RETROCAPTURE_REPOSITORY:-https://github.com/geldoronie/RetroCapture.git}"
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/retrocapture-graph-XXXXXX")"
trap 'rm -rf -- "$TEMP"' EXIT
command -v git >/dev/null
command -v c++ >/dev/null
command -v xvfb-run >/dev/null
command -v pkg-config >/dev/null
pkg-config --exists glfw3 libpng

if [[ -n "${RETROCAPTURE_SOURCE_DIR:-}" ]]; then
  # Offline reruns using an existing *sparse* checkout. Do not clone its
  # partial Git object store: local upload-pack retries missing blobs.
  upstream="$RETROCAPTURE_SOURCE_DIR"
  [[ "$(git -C "$upstream" rev-parse HEAD)" == "$REV" ]] || {
    echo "RetroCapture checkout must be pinned to $REV" >&2; exit 2;
  }
  mkdir -p "$TEMP/repo/src" "$TEMP/repo/shaders/shaders_glsl"
  for dir in shader renderer utils; do
    cp -a "$upstream/src/$dir" "$TEMP/repo/src/"
  done
  for dir in crt blurs presets anti-aliasing motionblur ntsc; do
    cp -a "$upstream/shaders/shaders_glsl/$dir" "$TEMP/repo/shaders/shaders_glsl/"
  done
  # The source checkout may contain experimental worktree changes: always
  # restore the exact committed engine before applying our reviewed patch.
  git -C "$upstream" show "$REV:src/shader/ShaderEngine.cpp" \
    > "$TEMP/repo/src/shader/ShaderEngine.cpp"
else
  git clone --quiet --filter=blob:none --sparse "$REPOSITORY" "$TEMP/repo"
  git -C "$TEMP/repo" checkout --quiet --detach "$REV"
  git -C "$TEMP/repo" sparse-checkout set src/shader src/renderer src/utils \
    shaders/shaders_glsl/crt shaders/shaders_glsl/blurs \
    shaders/shaders_glsl/presets shaders/shaders_glsl/anti-aliasing \
    shaders/shaders_glsl/motionblur shaders/shaders_glsl/ntsc
fi
(cd "$TEMP/repo" && patch --silent --dry-run -p1 < "$ROOT/patches/0001-restore-feedback-target.patch")
(cd "$TEMP/repo" && patch --silent -p1 < "$ROOT/patches/0001-restore-feedback-target.patch")

src="$TEMP/repo/src"
c++ -std=c++17 -O1 -pthread -I"$src" "$ROOT/verify_preset_pipeline.cpp" \
 "$src/shader/ShaderEngine.cpp" "$src/shader/ShaderPreprocessor.cpp" \
 "$src/shader/ShaderPreset.cpp" "$src/renderer/glad_loader.cpp" \
 "$src/utils/Logger.cpp" "$src/utils/Paths.cpp" \
 -o "$TEMP/verify-preset" $(pkg-config --cflags --libs glfw3 libpng) -lGL -pthread

# Redirect the library's logger and config away from user settings.
export XDG_CONFIG_HOME="$TEMP/config"
export XDG_DATA_HOME="$TEMP/data"
printf '\n[2-pass original CRT preset]\n'
xvfb-run -a "$TEMP/verify-preset" \
 "$TEMP/repo/shaders/shaders_glsl/crt/crt-blurPi.glslp" spatial
printf '\n[9-pass original Vector Glow preset]\n'
xvfb-run -a "$TEMP/verify-preset" \
 "$TEMP/repo/shaders/shaders_glsl/presets/vector-glow.glslp" spatial
printf '\n[seven-frame LCD response-time shader: history behavior]\n'
xvfb-run -a "$TEMP/verify-preset" \
 "$TEMP/repo/shaders/shaders_glsl/motionblur/response-time.glslp" history
printf '\n[synthetic PassFeedback0Texture ping-pong: first-frame and temporal behavior]\n'
xvfb-run -a "$TEMP/verify-preset" "$ROOT/fixtures/feedback.glslp" feedback

# More real multi-pass shader families: these are not placeholder passes.
for case in \
 "CRT_Lottes|crt/crt-lottes-multipass.glslp|2" \
 "CRT_Guest_SM|crt/crt-guest-sm.glslp|2" \
 "Kawase_Blur|blurs/kawase_blur_5pass.glslp|7" \
 "Kawase_Glow|blurs/kawase_glow.glslp|8" \
 "CRT_Guest_NTSC|presets/crt-guest-dr-venom-ntsc-composite.glslp|12"; do
  IFS='|' read -r name preset passes <<< "$case"
  printf '\n[%s — %s real passes]\n' "$name" "$passes"
  log="$TEMP/$name.log"
  xvfb-run -a "$TEMP/verify-preset" "$TEMP/repo/shaders/shaders_glsl/$preset" spatial > "$log" 2>&1 || {
    cat "$log" >&2; echo "PRESET_FAILED=$name" >&2; exit 1;
  }
  grep -q "PRESET_LOADED=1 PASSES=$passes" "$log"
  grep -q 'GLSLP_GRAPH_RENDER_PASS=1 MODE=spatial' "$log"
  grep -E 'PRESET_LOADED=|FRAME=0|GLSLP_GRAPH_RENDER_PASS=' "$log"
done

printf '\n[feedback resize: 160x120 -> 192x128 -> 160x120]\n'
xvfb-run -a "$TEMP/verify-preset" "$ROOT/fixtures/feedback.glslp" resize
printf '\n[feedback preset reload: history resets deterministically]\n'
xvfb-run -a "$TEMP/verify-preset" "$ROOT/fixtures/feedback.glslp" reload
printf '\n[nine-pass pipeline resize: buffers reallocate and return to reference]\n'
xvfb-run -a "$TEMP/verify-preset" \
 "$TEMP/repo/shaders/shaders_glsl/presets/vector-glow.glslp" resizestatic

# A known broken real preset MUST remain visible. Its two passes compile,
# but currently they produce flat black RGB on our controlled input.
# Treating that as success or hiding it would invalidate the suite.
printf '\n[expected black-output reproduction: CRT Hyllian multipass]\n'
log="$TEMP/hyllian.log"
if xvfb-run -a "$TEMP/verify-preset" \
 "$TEMP/repo/shaders/shaders_glsl/crt/crt-hyllian-multipass.glslp" spatial > "$log" 2>&1; then
  echo 'HYLLIAN_UNEXPECTEDLY_PASSED: investigate and promote to regular positive case' >&2
  cat "$log" >&2
  exit 1
fi
grep -q 'PRESET_LOADED=1 PASSES=2' "$log"
grep -q 'GLSLP_GRAPH_RENDER_PASS=0 MODE=spatial' "$log"
grep -E '^FRAME=0 .*VARIED=0 NONBLACK=0' "$log"
echo 'KNOWN_BLANK_OUTPUT_REPRODUCED=1 (no fix claimed)'

printf '\nRETROCAPTURE_GRAPH_PROOF_PASS=1 (standalone OpenGL, NOT integrated OBS UI)\n'
