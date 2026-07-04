# SESSION-STATE.md
**Project:** myrqyry-shaderfilter (fork of exeldro's obs-shaderfilter)
**Status:** Active development
**Last Updated:** 2026-05-30

## Key Context
- Fork of exeldro's shaderfilter OBS plugin
- HLSL shaders for OBS video filters
- User has attempted bug fixes and rearranged UI to personal taste
- UI preferences: customized layout (details pending)
- Rule: When uncertain about runtime/plugin behavior, do NOT toggle code based on memory — inspect source or ask for clarification first (user correction 2026-05-30)

## 2026-07-03 Code Review Follow-up
- User provided a detailed review of `obs-shaderfilter.c` with claimed issues around include error handling, unsafe/dead `convert_define`, missing null guard in `shader_filter_file_name_changed`, audio mutex read-side locking, `convert_atan` comment handling, committed `SESSION-STATE.md`, `rand()`, and unsupported `GS_SHADER_PARAM_INT3` UI handling.
- Active approach: treat review as leads, verify each claim against current checkout, then apply only minimal fixes that survive source inspection. Do not delete files without explicit approval.
- Applied minimal source-verified fixes in `obs-shaderfilter.c`: missing include errors now log and inject a shader comment, file-name callback now null-guards filter data, `convert_atan` advances past `//` comment newlines, unsafe dead `convert_define` helper removed, `rand()` removed from `rand_interval`, and unsupported `int3` parameters now show an OBS warning info row.
- Verified `cmake --build build_x86_64 --parallel` exits 0. Audio mutex read-side race claim did not reproduce in this checkout; render/tick read already locks `audio_mutex`.
- User requested commit and push of our changes. Need stage only review-follow-up changes, because the worktree already contains unrelated modified/untracked files from prior work.

## 2026-05-31 Decision
- Completed generative source implementation: added width/height to struct, default 1920x1080, updated get_width/get_height to prefer explicit dimensions, fixed shader_source_render, added UNUSED_PARAMETER guard. Compiles cleanly. Source "shader_source" now registered alongside filter/transition.
- Built and installed to ~/.config/obs-studio/plugins/obs-shaderfilter/ (user-local OBS plugins dir)
- Fixed regression: get_width/get_height now correctly prefer total_* (filter path) over explicit width/height (source path)
- Restored 1920x1080 default init (safe because get_* prefers total_* when filter has computed it)
- Verified full parameter path in shader_filter_tick + shader_filter_set_effect_params
- Restructured tick: sources now get proper uv_size/scale/offset/pixel_interval + elapsed_time accumulation (no early return when !target)
- Created data/examples/3d_text_sdf.shader (MQR 2.5D extruded text with bevel, Curve Simplify, and bob animation) — fixed cross-platform (removed unsupported `uniform string` + indexing)
- Created data/examples/canny_true.shader — proper single-pass Canny (gradient + direction + NMS + hysteresis + thickness)
- Initialized full proactive agent file set (AGENTS.md, SOUL.md, USER.md, MEMORY.md, HEARTBEAT.md, TOOLS.md, working-buffer.md) and added to .gitignore

## 2026-06-01 (This Session)
- Completed full proactive agent v3.0.0 architecture setup:
  - Created ONBOARDING.md (first-run setup tracker)
  - Upgraded SOUL.md (full identity + boundaries + ADL priorities)
  - Upgraded USER.md (detailed preferences, focus, communication style)
  - Upgraded MEMORY.md (structured learnings + anti-patterns + open questions)
  - Upgraded HEARTBEAT.md (full checklist from skill spec)
  - Upgraded TOOLS.md (comprehensive OBS/shaders/git/cmake/debug tooling)
  - Created memory/2026-06-01.md (daily log)
  - Reset memory/working-buffer.md to STANDBY
  - Created notes/areas/ (proactive-tracker, recurring-patterns, outcome-journal)
  - Updated AGENTS.md with all six pillars + protocols

## 2026-06-11 Inquiry
- User asked about converting ReShade FX shaders from reshade.me for obs-shaderfilter compatibility.
- Core blockers identified (from code review + obs-shaderfilter skills):
  - No depth buffer access (kills DOF, SSAO, MXAO, most screen-space 3D effects).
  - Single-pass only by default (plugin auto-wraps to `float4 mainImage(VertData v_in) : TARGET`; multi-pass techniques don't map).
  - Different uniform/parameter annotation system (`ui_*` → `widget_type` + `minimum`/`maximum` etc.).
  - Sampling: ReShade `texture()` / `tex2D` → `image.Sample(textureSampler, v_in.uv)`.
  - Entry point: ReShade `void mainImage(out vec4 c, in float2 uv)` or pass PS → this `mainImage`.
  - Temporal feedback possible via explicit `uniform texture2d previous_output;` (and `previous_image`).
  - Audio reactivity opt-in via `audio_peak` / `audio_magnitude`.
- Easy ports: pure 2D color/2D image effects (LUTs, blurs, CRT, glitch, sharpen, vignette, etc.).
- Decision: Provide concise conversion guide + checklist. Offer to port specific shaders. No new doc file yet unless user requests (keep lightweight per VFM).

## 2026-06-11 Follow-up: AI / ML Models
- User: "what about incorporating ai models?"
- Current reality (full codebase scan + plugin source review):
  - Zero AI/ML infrastructure. No ONNX, TensorRT, DirectML, CoreML, PyTorch, inference runtimes, model loading, or neural net anything.
  - Only "AI-adjacent" thing is the ancient `background_removal.effect` (static image color-key matte, tolerance-based, pre-2019, no ML).
  - This plugin is **shader-only** (HLSL pixel shaders wrapped by obs-shaderfilter.c). The C side just binds uniforms and textures; all logic lives in `mainImage(VertData v_in)`.
- Fundamental blockers for real models inside this plugin:
  - Shaders cannot host large weight tensors or do general matrix math at inference scale.
  - No host-side compute path exposed (no CUDA interop, no compute shaders for ML, no CPU→GPU model upload).
  - Realtime constraints + OBS graphics context (D3D11/GL/Metal) make heavy frameworks painful.
  - Single-pass + limited temporal (via previous_output) only.
- Feasible paths (ranked):
  1. External AI (most practical today): Run real models in separate tools/apps (e.g. obs-backgroundremoval plugin, Topaz, ComfyUI + virtual cam/NDI/Spout, browser source). Pipe the result into OBS as a source, then layer obs-shaderfilter on top for artistic polish.
  2. Companion native OBS plugin: Write a proper C++ plugin using ONNX Runtime (or DirectML/TensorRT) that performs inference and exposes output as a texture/source. Shaderfilter can then consume it via "Source" picker uniforms or as a chained filter.
  3. Shader "AI aesthetics" only: Tiny procedural approximations, baked LUTs + small shader networks, noise-driven generative effects (already possible with existing stdlib + examples). Not trained models.
  4. Hybrid: AI plugin produces mask/features → feed as texture source into a clever shaderfilter for refinement, edge cleanup, style, etc.
- Decision: Be direct about limits. Do not promise "run models in shaders". Offer to help with (a) shader post-processing of AI output, or (b) scoping a separate native inference plugin if that's the goal. Update MEMORY.md with this as a hard architectural boundary.
- No changes to current shaderfilter codebase make sense for "add AI" without turning it into a completely different (much larger) project.

## 2026-06-29 Shader Source UI Request
- User wants the shader source settings reversed: loading shader text from a file should be the common/default route, and a checkbox labeled "Raw Shader" should reveal the raw shader text field instead.
- Current code uses the persisted setting key `from_file`; false currently shows `shader_text`, true shows `shader_file_name`.
- Likely minimal design: keep `from_file` for scene-data compatibility, set its default to true, present an inverted UI control label/behavior only if OBS property APIs support it cleanly; otherwise use a compatibility-preserving derived `raw_shader` UI key with sync logic.
- User confirmed existing OBS scenes should keep their current mode; default only new filters to file mode.
- Implemented compatibility-preserving `raw_shader` UI key synced to inverse `from_file`; brand-new sources initialize to file mode only when neither `from_file` nor `shader_text` exists as a user value.
- User selected completion option 1 and requested local OBS user-plugin install.

## 2026-07-01 README / Shader Source Accuracy Review
- User provided an external review of the fork status and flagged three issues before treating README claims as authoritative.
- Verified in current code:
  - README claim "Shader files auto-reload" is inaccurate; only raw `shader_text` changes use the 300 ms debounce in `shader_filter_text_changed()`.
  - `shader_source` dimensions are still hard-coded to 1920x1080 in `shader_filter_create()` and no `source_width` / `source_height` properties exist.
  - Padding controls are shown for any non-transition instance via `if (!filter || !filter->transition)`, so the standalone source inherits filter-only padding controls that the source path ignores.
- Minimal preferred fix under discussion: add explicit source-mode flagging, add source width/height integer settings for `shader_source`, hide padding for source mode, and correct README auto-reload wording unless real file mtime polling is added.
- User approved the recommended design: implement real source width/height controls, explicit source-mode gating, source-only dimension usage, filter-only padding UI, and README wording that accurately describes raw-text debounce rather than file auto-reload.
- User corrected source display naming expectations: the filter must be named "Shaderfilter Shader", the standalone source must be named "Shaderfilter Source", and the transition must be named "Shaderfilter Transition". Do not use generic names like "User-defined Shader".
- User wants the padding section's separate question-mark help control removed; padding help should follow the vertex shader option's long-tooltip pattern instead.
- User clarified install target: install the rebuilt plugin into the actual OBS user plugin directory, not just the build rundir.
- User corrected filter display name again: it must be "Shaderfilter Filter", not "Shaderfilter Shader". Source and transition names remain "Shaderfilter Source" and "Shaderfilter Transition".
- User provided screenshot showing desired tooltip behavior: use OBS-native inline tooltip icon next to the actual option label, like "Full Vertex Shader (.effect)", not a separate question-mark button or row. Apply this to padding controls.
- User asked whether OBS tooltips can use multiple lines and approved trying escaped `\n` newlines in the padding tooltip locale string first.
- User confirmed escaped `\n` multiline tooltips work in OBS and wants the same treatment for the Full Vertex Shader option tooltip.

## 2026-06-12 Clarification on MediaPipe
- User is specifically considering **MediaPipe Tasks** (Google's Task API for selfie segmentation, face/pose/hands, etc.).
- User explicitly stated they are already working on a native plugin for the inference side.
- Confirmed: MediaPipe Tasks cannot be embedded in obs-shaderfilter. It is a full TFLite-based inference runtime with model loading, delegates (CPU/GPU), landmark output, mask generation, etc. Requires native C++/plugin code.
- Perfect division of labor:
  - User's native plugin: runs MediaPipe, produces output textures (masks, overlays, landmark visuals, etc.).
  - obs-shaderfilter: consumes those textures via the built-in `widget_type = "source"` mechanism (`uniform texture2d Mask < string widget_type = "source"; >;`), then applies fast real-time artistic effects, feathering, stylization, compositing, temporal feedback, etc.
- This repo already has everything needed on the shader side for high-quality post-processing of MediaPipe output (source picker + previous_output for feedback + full annotation UI system).
- No core changes required here. Value is in good example shaders + integration patterns.
- Logged as architectural split: inference plugin (separate) + shader effect layer (this repo).
- User asked for integration patterns; offered to write example shaders that assume MediaPipe mask + landmark textures as inputs.

## 2026-06-12 HyperShaderFX Cross-Repo Context
- User pointed to `~/MQR/hyperShaderFX` as the native MediaPipe/plugin project.
- Inspected `hyperShaderFX` enough to confirm it already has MediaPipe/ONNX architecture:
  - `src/mediapipe/mp_wrapper.h/.cpp` exposes graph types: selfie segmentation, face mesh, hand tracking, pose estimation, depth estimation, Canny, privacy.
  - `src/shadertoy_data.h` has `mp_runner`, `mp_mask_tex`, `mp_landmarks_tex`, `mp_ref_landmarks_tex`, and effect params `ep_iSegmentation`, `ep_iLandmarks`, `ep_iReferenceLandmarks`.
  - `src/filter-hypershader.c` has a dedicated `mp_worker_thread`, frame readback/staging, graphics-thread texture uploads, and render-time texture binding blocks.
  - `data/stdlib/mediapipe.glsl` declares `uniform texture2d iSegmentation`, `iLandmarks`, `iReferenceLandmarks` and helper macros.
- Important finding: `shader_load_complete_task()` refreshes cached params for `iTime`, `iScale`, `iResolution`, `iMouse`, `iPreviousFrame`, channels, and audio bands, but does **not** refresh `ep_iSegmentation`, `ep_iLandmarks`, or `ep_iReferenceLandmarks`. Since render-time binding checks those cached pointers, MediaPipe textures may not bind into shaders unless handled elsewhere (grep did not show it elsewhere). Likely fix is to cache those three params after `s->effect` is swapped.
- Recommendation for next step: patch hyperShaderFX, not myrqyry-shaderfilter. Minimal fix: add `gs_effect_get_param_by_name(s->effect, "iSegmentation")`, `"iLandmarks"`, `"iReferenceLandmarks"` after `ep_iPreviousFrame` refresh.
- Applied that minimal fix in `/home/myrqyry/MQR/hyperShaderFX/src/filter-hypershader.c`.
- Verification: `cmake --build build_x86_64 --target hyperShaderFX --parallel` passed and linked `hyperShaderFX.so`.
- Follow-up user request: "if you spot any other issues to fix".
- Additional concrete hyperShaderFX MediaPipe fixes applied:
  - Root cause: `mp_enabled` was initialized false and never set true anywhere, making capture/upload/bind paths inert. Fixed `filter_update()` to derive it from `mp_runner && mp_thread_run && graph != MP_GRAPH_NONE` and set false when no runner exists.
  - Fixed `mp_destroy()` guard to destroy any existing runner, not only when `mp_enabled` is true (otherwise disabled/unstarted runner could leak).
  - Fixed failed `obs_source_process_filter_begin_with_color_space()` early return to call `obs_source_skip_video_filter()` first.
  - Root cause: Reference analysis button only set `mp_analyze_trigger`; nothing consumed it and `mp_ref_landmarks_tex` was never populated. Added worker-side trigger consumption, reference landmark copy, graphics-thread upload to `mp_ref_landmarks_tex`, cleanup paths, and mutex protection in `analyze_image_clicked()`.
- Files changed in `hyperShaderFX`: `src/filter-hypershader.c`, `src/hyper_ui.c`.
- Verification:
  - `cmake --build build_x86_64 --target hyperShaderFX --parallel` passed; later rerun reported `ninja: no work to do`.
  - `npm run verify:settings` passed (`sourceKeys=35, uiKeys=34`).
  - `./build-aux/run-clang-format --fail-error --check src/filter-hypershader.c` passed.
  - `git diff --check -- src/filter-hypershader.c src/hyper_ui.c` passed.
  - Full `hyper_ui.c` clang-format check still fails on many pre-existing unrelated regions; did not auto-format whole file to avoid noisy unrelated edits.

## 2026-06-12 HyperShaderFX ONNX Backend Follow-up
- Found local ONNX Runtime files at `/home/myrqyry/MQR/live-latent-lab-sound/build_x86_64/_deps/onnxruntime-src/{include,lib}`.
- Reconfigured `/home/myrqyry/MQR/hyperShaderFX/build_x86_64` with:
  - `USE_ONNX_RUNTIME=ON`
  - `ONNXRUNTIME_INCLUDE=/home/myrqyry/MQR/live-latent-lab-sound/build_x86_64/_deps/onnxruntime-src/include`
  - `ONNXRUNTIME_LIB=/home/myrqyry/MQR/live-latent-lab-sound/build_x86_64/_deps/onnxruntime-src/lib/libonnxruntime.so`
- CMake now reports `ONNX Runtime found — enabling real MediaPipe inference`; `ldd build_x86_64/hyperShaderFX.so` resolves `libonnxruntime.so.1.17.1` from that local dependency directory.
- Verified bundled ONNX model I/O with Python `onnx`:
  - `face_detector.onnx`: input `image`, outputs `box_coords_1`, `box_coords_2`, `box_scores_1`, `box_scores_2`.
  - `face_landmark_detector.onnx`: input `image`, outputs `scores`, `landmarks`.
  - Existing hardcoded requested output names match the needed outputs.
- Added `scripts/verify-mediapipe-wrapper.js` and `npm run verify:mediapipe`.
  - Red run failed as expected: decoded face batches were not stored, ONNX errors still fell through to simulator output, and static image analysis still returned simulated reference landmarks as success.
  - Green run passed after patching.
- Patched `/home/myrqyry/MQR/hyperShaderFX/src/mediapipe/mp_wrapper.cpp`:
  - Store decoded detections in `runner->all_faces` for both LiteRT and ONNX paths, fixing privacy mode's bystander loop input.
  - Clear `runner->all_faces` when no face is detected.
  - Return `false` on ONNX exceptions instead of falling through to simulator output.
  - Return `false` when real ONNX/LiteRT backend exists but no implemented model path exists for the selected graph, instead of emitting simulated output.
  - Removed static-image simulator fallback from `mp_process_image()` so reference capture only succeeds with real detected landmarks.
- Verification after these changes:
  - `cmake --build build_x86_64 --target hyperShaderFX --parallel` passed.
  - `npm run verify:settings` passed (`sourceKeys=35, uiKeys=34`).
  - `npm run verify:mediapipe` passed.
  - `./build-aux/run-clang-format --fail-error --check src/filter-hypershader.c src/mediapipe/mp_wrapper.cpp` passed.
  - `git diff --check -- src/filter-hypershader.c src/hyper_ui.c src/mediapipe/mp_wrapper.cpp package.json scripts/verify-mediapipe-wrapper.js` passed.
- Caveat: Full `hyper_ui.c` clang-format check still fails on unrelated pre-existing regions; left untouched to avoid noisy churn.

## 2026-06-13 HyperShaderFX Remaining Runtime Fixes
- User asked to continue fixing the rest. Continued in `/home/myrqyry/MQR/hyperShaderFX`.
- Extended `scripts/verify-mediapipe-wrapper.js` to catch:
  - LiteRT hand tracking returning simulated hand results after a successful palm detector run.
  - Stale documented model names `face_detection_short_range.onnx` and `face_landmark.onnx`.
  - Stale documented build flag `USE_ONNX_MEDIAPIPE=ON`.
  - README text claiming simulator fallback when real backend is required.
- Red run of `npm run verify:mediapipe` failed on those expected issues before patching.
- Patched `/home/myrqyry/MQR/hyperShaderFX/src/mediapipe/mp_wrapper.cpp`:
  - Updated top-of-file ONNX comments to match actual model filenames and NCHW shapes.
  - Replaced stale build comment with `USE_ONNX_RUNTIME=ON`.
  - Removed non-real LiteRT hand result emission; decoder now clears results and logs that simulated output is refused.
- Updated `/home/myrqyry/MQR/hyperShaderFX/data/models/mediapipe/README.md`:
  - Required filenames now match actual code/files: `face_detector.onnx`, `face_landmark_detector.onnx`.
  - Model specs now match actual I/O names/shapes.
  - Build instructions now use `USE_ONNX_RUNTIME=ON`, `ONNXRUNTIME_INCLUDE`, and `ONNXRUNTIME_LIB`.
  - Failure log now documents real-backend-required behavior instead of simulator fallback.
  - Verification log now uses actual `Found ONNX models at` wording.
- Ran OBS plugin pattern checker from `obs-plugin-dev-assistant`:
  - Initial run found one concrete error: `mix_render_callback` could early-return without drawing, blanking transition output.
  - Patched transition callback fallback in `src/filter-hypershader.c` to draw one input texture when shader state is unavailable and removed early returns from the callback.
  - Follow-up checker run still had one info item: hot-reload logging inside `filter_video_render()`.
  - Removed debug hot-reload log calls from the render callback while preserving backup/recovery state transitions.
  - Final checker run reported `Found 0 error(s), 473 warning(s), 0 info item(s)`.
  - Remaining warnings are broad heuristics: mostly vendored `src/audio/miniaudio.h` and C/C++ array indexing misclassified as `std::map::operator[]`, plus intentional raw `pthread` synchronization with stop/join paths. No additional concrete local blocker was patched.
- Verification after latest changes:
  - `cmake --build build_x86_64 --target hyperShaderFX --parallel` passed.
  - `npm run verify:settings` passed (`sourceKeys=35, uiKeys=34`).
  - `npm run verify:mediapipe` passed.
  - `./build-aux/run-clang-format --fail-error --check src/filter-hypershader.c src/mediapipe/mp_wrapper.cpp` passed.
  - `git diff --check -- src/filter-hypershader.c src/hyper_ui.c src/mediapipe/mp_wrapper.cpp package.json scripts/verify-mediapipe-wrapper.js data/models/mediapipe/README.md` passed.

## 2026-06-13 HyperShaderFX Local OBS Install Fix
- User asked whether the plugin was installed, then approved installation, then asked to fix CMake so it installs correctly.
- Added `ubuntu-local-install-x86_64` configure/build presets in `/home/myrqyry/MQR/hyperShaderFX/CMakePresets.json`:
  - `CMAKE_INSTALL_PREFIX=$HOME/.config/obs-studio/plugins/hyperShaderFX`
  - `OBS_PLUGIN_DESTINATION=bin/64bit`
  - `OBS_DATA_DESTINATION=data`
- Fixed `/home/myrqyry/MQR/hyperShaderFX/CMakeLists.txt`:
  - Removed duplicate ONNX Runtime install to `${CMAKE_INSTALL_LIBDIR}/obs-plugins`.
  - Added `INSTALL_RPATH "$ORIGIN"` so installed `hyperShaderFX.so` resolves bundled runtime libraries beside itself.
  - Kept the existing install rule that copies ONNX Runtime libraries to `bin/64bit`.
- Reconfigured and installed with:
  - `cmake --preset ubuntu-local-install-x86_64 -DUSE_ONNX_RUNTIME=ON -DONNXRUNTIME_INCLUDE=/home/myrqyry/MQR/live-latent-lab-sound/build_x86_64/_deps/onnxruntime-src/include -DONNXRUNTIME_LIB=/home/myrqyry/MQR/live-latent-lab-sound/build_x86_64/_deps/onnxruntime-src/lib/libonnxruntime.so`
  - `cmake --build --preset ubuntu-local-install-x86_64 --target hyperShaderFX --parallel`
  - `cmake --install build_x86_64`
- Installed files verified:
  - `/home/myrqyry/.config/obs-studio/plugins/hyperShaderFX/bin/64bit/hyperShaderFX.so`
  - `/home/myrqyry/.config/obs-studio/plugins/hyperShaderFX/bin/64bit/libonnxruntime.so.1.17.1`
  - `/home/myrqyry/.config/obs-studio/plugins/hyperShaderFX/data/models/mediapipe/face_detector.onnx`
  - `/home/myrqyry/.config/obs-studio/plugins/hyperShaderFX/data/models/mediapipe/face_landmark_detector.onnx`
- `ldd /home/myrqyry/.config/obs-studio/plugins/hyperShaderFX/bin/64bit/hyperShaderFX.so` resolves `libonnxruntime.so.1.17.1` from `/home/myrqyry/.config/obs-studio/plugins/hyperShaderFX/bin/64bit/libonnxruntime.so.1.17.1`.
- User approved deleting old related files. Removed the stale duplicate install tree at `/home/myrqyry/.config/obs-studio/plugins/hyperShaderFX/lib`.
- Verified no files remain under `/home/myrqyry/.config/obs-studio/plugins/hyperShaderFX/lib/**`.
- Re-ran `ldd /home/myrqyry/.config/obs-studio/plugins/hyperShaderFX/bin/64bit/hyperShaderFX.so`; it still resolves `libonnxruntime.so.1.17.1` from `/home/myrqyry/.config/obs-studio/plugins/hyperShaderFX/bin/64bit/libonnxruntime.so.1.17.1`.
- Post-install verification passed:
  - `npm run verify:settings`
  - `npm run verify:mediapipe`
  - `./build-aux/run-clang-format --fail-error --check src/filter-hypershader.c src/mediapipe/mp_wrapper.cpp`
  - `git diff --check -- CMakeLists.txt CMakePresets.json src/filter-hypershader.c src/hyper_ui.c src/mediapipe/mp_wrapper.cpp package.json scripts/verify-mediapipe-wrapper.js data/models/mediapipe/README.md`

## 2026-06-13 HyperShaderFX Settings UI Redesign
- User approved a split between a compact filter settings UI and advanced dock workflows.
- Added `/home/myrqyry/MQR/hyperShaderFX/docs/superpowers/plans/2026-06-13-settings-ui-redesign.md`.
- Extended `/home/myrqyry/MQR/hyperShaderFX/scripts/verify-settings.js` with:
  - `DOCK_ONLY_KEYS` to prevent raw editor, import/export, LLM, and advanced audio controls from appearing in filter properties.
  - `REQUIRED_FILTER_UI_KEYS` to keep the core filter controls present.
- Reworked `/home/myrqyry/MQR/hyperShaderFX/src/hyper_ui.c`:
  - Replaced page/tab-style filter settings with `Current Shader`, `Core Controls`, `Advanced Workspace`, and status/workflow grouping.
  - Removed filter-facing import/export/raw editor/playground controls and their obsolete page/import visibility callbacks.
  - Kept the filter UI focused on selecting a shader, runtime controls, MediaPipe quick selection, channel inputs required by the current shader, audio runtime controls, and status.
  - Added initial channel visibility from current source state without calling `obs_source_get_settings()` during property construction.
  - Kept saved default keys such as `ui_page`, `raw_edit_mode`, and advanced audio defaults for scene compatibility even though they are now dock-only/internal.
- Updated `/home/myrqyry/MQR/hyperShaderFX/src/filter_callbacks.h` to remove obsolete page/import callback declarations.
- Verification passed:
  - `cmake --build build_x86_64 --target hyperShaderFX --parallel`
  - `npm run verify:settings` (`sourceKeys=34, uiKeys=16`)
  - `npm run verify:mediapipe`
  - `./build-aux/run-clang-format --fail-error --check src/filter-hypershader.c src/mediapipe/mp_wrapper.cpp`
  - `git diff --check -- CMakeLists.txt CMakePresets.json src/filter-hypershader.c src/hyper_ui.c src/filter_callbacks.h src/mediapipe/mp_wrapper.cpp package.json scripts/verify-settings.js scripts/verify-mediapipe-wrapper.js data/models/mediapipe/README.md docs/superpowers/plans/2026-06-13-settings-ui-redesign.md`
- Installed rebuilt plugin to `/home/myrqyry/.config/obs-studio/plugins/hyperShaderFX/bin/64bit/hyperShaderFX.so`.
- `ldd /home/myrqyry/.config/obs-studio/plugins/hyperShaderFX/bin/64bit/hyperShaderFX.so | rg 'not found|libonnxruntime'` only reports the local ONNX Runtime path, confirming no unresolved dependencies in that focused check.
- Caveat: `ENABLE_QT=false` and `ENABLE_FRONTEND_API=false` remain in the current local preset, so the advanced dock is still unavailable unless the build is reconfigured with dock support.

## 2026-06-13 HyperShaderFX Dock Support Probe
- User approved proceeding with the advanced Shader Builder dock path.
- Wrote local plan file `/home/myrqyry/MQR/hyperShaderFX/docs/superpowers/plans/2026-06-13-enable-shader-builder-dock.md`.
- Probed dock build dependencies with:
  - `cmake --preset ubuntu-local-install-x86_64 -DENABLE_FRONTEND_API=ON -DENABLE_QT=ON -DUSE_ONNX_RUNTIME=ON -DONNXRUNTIME_INCLUDE=/home/myrqyry/MQR/live-latent-lab-sound/build_x86_64/_deps/onnxruntime-src/include -DONNXRUNTIME_LIB=/home/myrqyry/MQR/live-latent-lab-sound/build_x86_64/_deps/onnxruntime-src/lib/libonnxruntime.so`
- Probe result: configuration failed at `CMakeLists.txt:123` with `ENABLE_QT is ON, but Qt6 was not found`.
- Decision: Do not persist `ENABLE_QT=ON` or `ENABLE_FRONTEND_API=ON` in the local preset because it would break local builds on this machine.
- Restored local non-dock configuration with `ENABLE_QT=OFF` and `ENABLE_FRONTEND_API=OFF` while keeping ONNX Runtime enabled.
- Patched `/home/myrqyry/MQR/hyperShaderFX/src/hyper_ui.c` so **Open Shader Dock** logs the exact needed flags when dock support is not built: `ENABLE_QT=ON` and `ENABLE_FRONTEND_API=ON`.
- Verification passed:
  - `cmake --build --preset ubuntu-local-install-x86_64 --target hyperShaderFX --parallel`
  - `npm run verify:settings`
  - `npm run verify:mediapipe`
  - `./build-aux/run-clang-format --fail-error --check src/filter-hypershader.c src/mediapipe/mp_wrapper.cpp`
  - `git diff --check -- src/hyper_ui.c`
  - `cmake --install build_x86_64`
  - `ldd /home/myrqyry/.config/obs-studio/plugins/hyperShaderFX/bin/64bit/hyperShaderFX.so | rg 'not found|libonnxruntime|Qt6|obs-frontend'`
- HyperShaderFX commit: `b6b9005 fix(ui): explain missing shader builder dock support`.
- Remaining blocker for actual dock support: install/discover Qt6 components required by CMake: `Qt6::Widgets`, `Qt6::WebEngineWidgets`, and `Qt6::WebChannel`, then re-run the dock-enabled configure probe.

## 2026-06-13 HyperShaderFX Dock Support Enabled
- User installed missing Qt6 dev packages: `qt6-webchannel-dev`, `qt6-webengine-dev`, `qt6-webengine-dev-tools`.
- Re-probed dock configuration: CMake configured successfully with `ENABLE_QT=ON` and `ENABLE_FRONTEND_API=ON`.
- Persisted `ENABLE_FRONTEND_API=true` and `ENABLE_QT=true` in the `ubuntu-local-install-x86_64` preset.
- First build failed with three errors in `src/ui/shader_builder_dock.hpp`:
  - Missing `#include <obs-frontend-api.h>` caused `obs_frontend_event`, `obs_source_t`, and `obs_hotkey_id` to be undeclared.
  - Hotkey callback signature was `bool (*)(void*, obs_hotkey_id, bool)` but OBS expects `void (*)(void*, obs_hotkey_id, obs_hotkey_t*, bool)`.
- Fixed `src/ui/shader_builder_dock.hpp`: added `#include <obs-frontend-api.h>`.
- Fixed `src/ui/shader_builder_dock.cpp`: changed hotkey callback to `void` return with correct OBS signature and `UNUSED_PARAMETER` guards.
- Second build passed with dock support compiled in.
- Verification passed:
  - `cmake --build --preset ubuntu-local-install-x86_64 --target hyperShaderFX --parallel`
  - `npm run verify:settings`
  - `npm run verify:mediapipe`
  - `./build-aux/run-clang-format --fail-error --check src/filter-hypershader.c src/mediapipe/mp_wrapper.cpp`
  - `git diff --check -- CMakePresets.json src/ui/shader_builder_dock.hpp src/ui/shader_builder_dock.cpp`
  - `cmake --install build_x86_64`
  - `ldd /home/myrqyry/.config/obs-studio/plugins/hyperShaderFX/bin/64bit/hyperShaderFX.so | rg 'not found|libonnxruntime|Qt6|obs-frontend'` — all Qt6, frontend API, and ONNX Runtime libraries resolve with no `not found` lines.
- HyperShaderFX commit: `b675162 build(plugin): enable local shader builder dock`.
- Installed plugin now includes the Shader Builder dock; **Open Shader Dock** button in filter properties will call `shader_builder_dock_show()` at runtime.
