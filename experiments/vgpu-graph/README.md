# vGPU capability lab (real WebGPU)

Investigated October 13, 2026. Source: https://github.com/vercel-labs/vgpu, npm version 0.6.0. MIT library; third-party shader packs have their own licenses.

This isolated Node project is a real Dawn/WebGPU render and compute proof, NOT OBS integration. Nothing is installed into OBS, and the root ShaderFilter build does not acquire a Node dependency. Continue GLSLP work in experiments/retrocapture-graph.

## Hardware verification — native pixels, not mocks

Node 22.18.0, pnpm 11.17.0, vgpu 0.6.0, @vgpu/wgsl 0.6.0, Dawn webgpu 0.4.0. Synthetic 64x64 GPU frames.

| Capability | Ryzen 7 7700 integrated Radeon / RADV Mesa 25.2.8 | RTX 2070 Super / NVIDIA 595.99.02 |
|---|---|---|
| Native device and doctor | healthy | healthy |
| Feedback RGBA checksums (4 frames) | 2351104, 2063936, 1860160, 1720960 | 2351104, 2063936, 1860096, 1720832 |
| Target resize | 32x24 gives 3072 RGBA bytes | same |
| Storage compute | [1,2,3,4] → [4,7,10,13] | same |

Slight feedback numerical differences on different Vulkan devices are expected. Test tolerance/property assertions rather than requiring exact RGB checksums across GPUs. Neither hardware run measures steady-state FPS or establishes an OBS integration.

## Reproduce

On this computer, use the supported Node 22 shell (no Docker or sudo):

    export PATH="$HOME/.nvm/versions/node/v22.18.0/bin:$PATH"
    cd ~/loam/obs-shaderfilter/experiments/vgpu-graph
    pnpm install --frozen-lockfile --ignore-scripts
    node node_modules/vgpu/bin/vgpu.js doctor
    node node_modules/vgpu/bin/vgpu.js check basic.wgsl --require-validation
    node probe.mjs
    node compute.mjs

To select the RTX for one command:

    VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json node probe.mjs
    VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json node compute.mjs

To select RADV, substitute /usr/share/vulkan/icd.d/radeon_icd.json. The default selected RADV on this host. Never change the system-wide Vulkan configuration just for this test.

The pnpm 11 install emitted ERR_PNPM_IGNORED_BUILDS for adapter-node and webgpu postinstall hooks, but the prepackaged Dawn Linux-x64 binary **worked**. On this host, pnpm exec vgpu tried to rerun install checks and failed. Direct Node invocation of the installed vgpu CLI works. Don't approve broad lifecycle scripts simply to silence this warning. The internal monorepo @vgpu/cli is not a separate published npm package; vgpu itself includes the binary.

The CLI was independently checked: help, docs find effect, doctor with actual offscreen readback, check basic.wgsl with reflection and native validation, and examples search fluid. Doctor incorrectly warned about Mesa 1.4 despite vulkaninfo showing Mesa 25.2.8 and a healthy renderer; don't upgrade OS drivers based on that warning alone.

## Capabilities and constraints from source/docs

- Browsers use the vgpu entrypoint and a canvas Surface; Node uses vgpu/node, explicit offscreen targets, pixel readback; vgpu/mock checks API calls and lifetimes but **not real shader output**.
- WGSL source must be a prepared reflection artifact. Use the loader for imported .wgsl, or prepareShader() from @vgpu/wgsl/prepare for runtime strings. Raw WGSL passed directly into effect() is rejected.
- Explicit frame(gpu, syncCallback) schedules render/compute passes. Keep frame callbacks synchronous. effect.compile(target) warms pipelines; timer requires timestamp-query opt-in.
- target(gpu) supports size changes. Binding a target tracks the replacement attachment; binding target.color captures that particular texture and requires re-binding on resize.
- pingPong(gpu) alternates two offscreen targets and explicitly swaps. It is NOT RetroArch's multi-frame OriginalHistory scheme; clearing, resampling, history depth and persistence across reload/resize belong to the application.
- gpu.onError handles async failures. gpu.settled() is a completion barrier, not proof of success. GPU device loss requires recreation and reinitialization.
- The library supports render passes, compute, storage buffers/textures, WGSL modules, @vgpu/wgsl-std helpers, bundles, and a browser rendering path. Node does not provide a standard window or canvas.
- CLI agent workflow: docs cat getting-started.md, docs find, check --require-validation, doctor, examples search/pull and mcp. Prefer these versioned docs and actual GPU tests over memorized API snippets.

## Where to use this

1. A standalone WebGPU creative shader lab: image/video → render graph → temporal processing → browser canvas; same WGSL used for headless GPU pixel-diff tests. First useful demos: 2-pass bloom and additive phosphor feedback.
2. VEX/vision: region-of-interest GPU crop, temporal masks, filtering, compositing and visualization. Official vGPU depth estimation and MNIST examples show GPU-device interop with ONNX Runtime Web in their specified browser settings; Android/WebView support and zero-copy behavior in our own inference stack remain **unverified**.
3. ViiRM/Three.js: experiment with WGSL modules through Three.js TSL, without modifying the VRM export path until tested.
4. OpenCode/Meristem: use local vgpu CLI, examples, package-scoped documentation and direct Dawn readback assertions to enforce no-fake-shader implementations.
5. Local Electron/browser creative tooling: interactive canvas renderer in Chromium; headless Node process for capture-quality offline export. They are different runtime contexts, not inherently shared textures.

## What not to do

- vGPU does NOT load GLSL or .glslp shader presets, and OBS libobs effects are compiled through a different graphics API. No drop-in OBS integration.
- Readback/encoding to feed OBS incurs real transfer costs; a future bridge needs end-to-end performance and alpha/color-space tests.
- Native RetroCapture already executes GLSLP; keep that work separate instead of rewriting it for the sake of using a new library.
- Don't assume the tested tiny frames prove 1080p60. The npm Node dependency tree is around 99 MB in the sandbox, unlike a tiny browser bundle.
- Repo issues #491 (WGSL validation timing), #483 (bind-group overhead) and #489 (reported encoding regression) are open issue **reports**, not local reproduction on 0.6.0. Recheck and benchmark if adopted.

## Next meaningful gate

Implement a separate browser/Node preview from a real image/video source with two effects and a bounded ping-pong history. Verify visual output, full-resolution performance and device loss/resize/reset, then compare the cost of presenting it in OBS. Do not patch the working OBS plugin based on standalone WebGPU tests alone.

## 2026-11-15 — Local image feedback preview and numerical parity

The next gate above now has an image-only implementation. The same
`image-feedback.mjs` runs on Node/Dawn and browser WebGPU:
upload straight RGBA8, apply a horizontal 1:2:1 spatial RGB filter,
and use a bounded two-target history for the temporal pass. The seed
frame copies the spatial result; subsequent frames mix 0.5 of the new
spatial color with 0.375 of the previous output. Source alpha is preserved.
Explicit reset and dimension changes reseed history. No third-party
shader is translated or loaded by this graph.

    pnpm install --frozen-lockfile --ignore-scripts
    pnpm dev

Open the loopback URL printed by Vite and select a local PNG, JPEG or
WebP image (up to 2048 x 2048). Advance Frame, Reset History, and Export
PNG are explicit controls. Preview presentation samples the graph's
output directly on a vGPU canvas surface; CPU readback is requested only
for PNG export. The canvas uses premultiplied display alpha; the graph
stores straight RGBA. No upload or service connection. The preview is
a manual image experiment, not a continuous video renderer.

Build and test:

    pnpm build
    pnpm test
    xvfb-run -a -s '-screen 0 1440x900x24' pnpm test:preview

Node tests require ImageMagick's convert command for the existing
tracked PNG fixture. The browser smoke uses an installed Chrome Beta
by default (set BROWSER_BIN to override); it launches a short-lived
loopback production preview server and removes temporary downloads.
Vite 7.3.6 and puppeteer-core 24.25.0 are pinned experiment-only
development dependencies; no browser download is required. The browser
smoke flags are Linux/Vulkan oriented, not portable qualification.

Verified on Node 24.20.0 and vGPU 0.6.0, Radeon RADV Mesa 25.2.8
and NVIDIA 595.99.02, with both native suites passing 2/2. Independent
CPU reference checks cover all channels of odd-width asymmetric images,
feedback, reset, portrait/landscape resize, invalid upload and overlap
rejection, and every pixel of the existing 306x322 giraffe PNG. Maximum
absolute RGBA8 channel error was one; alpha exact. Browser production
smoke on NVIDIA Turing passed actual file selection, visible canvas
changes, feedback, PNG download and bit-identical reset export with
zero console/page/HTTP errors and external requests. Browser bundle
218.21 kB JavaScript (69.48 kB gzip). Existing synthetic render/resize
and compute probes still pass. The first browser run reported a missing
favicon (fixed by a local data favicon).

The graph borrows the caller's GPU and owns its textures, effect
instances, and render targets. A render completes before returning its
borrowed target. Consume that target before another render; do not retain
it through resize/disposal. Consecutive calls are serialized; overlap,
reset or disposal during a render is rejected. Validation errors prevent
history swap. Do not concurrently manipulate the same native error-scope
stack from another caller. GPU device-loss recovery requires recreation;
the preview reports loss rather than silently falling back.

Unverified: sustained video throughput, performance at 1080p/4K,
multi-frame asynchronous pipelining, cross-device/browser portability,
device-loss recovery, OBS transfer and native plugin integration. This
experiment does not change the C/C++ plugin, installed OBS, scenes,
profiles or user shader files.

## 2026-11-15 — Decoded local video feedback

The preview now also accepts a local video, up to 2048 x 2048,
with muted autoplay and native playback/seek controls. Decoded
frame callbacks drive a single in-flight render. Slow GPU work can
skip source frames rather than queueing an unbounded history.
The video path copies the presented HTMLVideoElement into the
existing GPU RGBA texture via copyExternalImageToTexture and submits
spatial filtering, temporal feedback, and canvas presentation together.
No JavaScript RGBA extraction or explicit GPU readback during playback.
The browser/driver may still perform internal conversions or copies;
this is not proof of zero-copy decode. PNG export is available paused.

Seeking invalidates the current history and reseeds on the new source
frame. Paused seeking has an animation-frame fallback if the compositor
callback was missed. Epoch checks suppress stale completion receipts;
an already submitted GPU frame cannot be recalled. A newly loaded
video starts muted to avoid missing the initial compositor callback.
The original image workflow remains available.

    pnpm build
    xvfb-run -a -s '-screen 0 1440x900x24' pnpm test:video

The video smoke generates a temporary 1920x1080 30fps VP9 clip using
ffmpeg/libvpx-vp9, plays it in Chrome Beta on NVIDIA Turing, observes
actual video texture copy calls, GPU mapAsync readbacks and Canvas2D
getImageData calls, and checks the actual paused seek PNG against an
explicit reset. ImageMagick reads the exported pixel. No external
requests or browser/HTTP errors. Three consecutive final runs each
completed 37, 38 or 39 output frames over approximately three seconds
(12.3–13 fps), with zero readbacks or pixel extraction during playback.
Seek to the blue segment produced RGB [0,15,255], with no residual red,
and the reset export was byte identical. Pause stopped frame advancement.

The original two-submission experiment completed 23 frames in three
seconds; a first single-submission run completed 36. These are short
observations, not a controlled performance benchmark. The initial
loadeddata-only copy failed on this driver (no backing resource);
wrapping the early source as VideoFrame also failed. The presented
frame callback plus muted playback resolved the observed startup
failure. The original smoke's 10fps threshold was replaced by a
correctness-only minimum of 10 completed frames in three seconds;
the measured rates are reported separately. A full 30fps source rate
is not established. Image browser smoke, both native GPU parity suites
and original render/compute probes passed; frozen install and build
passed. No new dependency was required.

Limitations: single validated video codec/adapter/browser fixture,
no continuous audio sync measurement, no arbitrary rapid seek or
device loss recovery qualification, no long-duration/4K or OBS
interop verification. History is defined over processed frames,
not every decoded source frame.

## 2026-11-15 — Direct video textures and completion-fence reduction

The next-video input selector offers **Texture copy** (default) and
**Direct external texture**. Choose the mode before selecting a video.
The direct mode uses the native GPUDevice.importExternalTexture API
and vGPU draw.layout()/draw.group() with a freshly created bind group.
It samples texture_external in the spatial shader and explicitly
quantizes the sample to the old RGBA8 boundary. No intermediate upload
texture is allocated in that mode. The normal copy route remains
available, and still-image processing retains the original image graph.

The pinned vGPU 0.6.0 automatic set() resource normalization rejects
external textures; the public native group-claim API works. Import,
bind and submission happen synchronously before awaiting completion,
rather than retaining a video external texture across browser tasks.
This is not proof of zero-copy hardware decoding.

The graph used both frame.done and gpu.settled() for every submission.
The installed frame.done implementation already fences the device queue
and delivers claimed-group validation. The graph now pops its native
validation scope immediately and awaits that result and frame.done
together before committing history. It remains single-flight. A new
regression counted 76 completion calls for 38 completed frames before
the fix; the final tests observed one completion fence per submitted
video frame (with an optional one frame still in flight at measurement).
A thrown presentation callback cancels the frame without advancing
history; the native direct-mode retry matched the copy reference.

Reproduce with the existing Node/Chrome/ffmpeg/ImageMagick setup:

    pnpm build
    xvfb-run -a -s '-screen 0 1440x900x24' pnpm test:external
    VIDEO_INPUT=copy xvfb-run -a -s '-screen 0 1440x900x24' pnpm test:video
    VIDEO_INPUT=external xvfb-run -a -s '-screen 0 1440x900x24' pnpm test:video

On NVIDIA Turing, the 318x182 decoded VP9 pattern's three successive
feedback outputs from a single paused source frame had zero absolute
pixel error against the copy path (231,504 RGBA bytes each), including
a fourth comparison after an injected presentation failure. These
are same-source recurrence comparisons, not arbitrary codec parity.
Both 1080p30 modes initially completed 38 output frames per three
seconds; with the redundant wait removed, copy completed 46 and 47,
direct completed 46 and 44 in two short runs each. Approximately
14.7–15.7 output fps, not full-source-rate playback or a controlled
benchmark. Direct mode had zero explicit texture-copy calls, copy
mode had zero external imports; both had zero explicit GPU readbacks
and Canvas2D pixel extraction during playback. Seek/reset byte-identical
PNG, pause, no browser/HTTP errors and no external requests passed in
both modes. Original image smoke, Radeon/NVIDIA 2/2 native parity,
render/resize/compute probes, build and frozen install passed.

Retain copy as default for broader compatibility: no consistent
direct-sampling throughput advantage was measured. No automatic
fallback on unsupported direct imports; choose copy before reloading
the video. Full frame rate, pipelining, arbitrary codec/color-space
parity, long-duration and repeated rapid seek stress, device-loss
recovery and OBS interop remain unqualified. No new dependency or
native OBS change.

## 2026-11-15 — Bounded two-frame video queue

The next-video queue selector offers Single frame (default) and Two
frames. It is independent of texture copy versus direct external input.
Choose before selecting the file. The optional two-frame mode submits
the next presented frame while the preceding GPU fence is outstanding.
The graph uses queue-ordered uploads, spatial passes and alternating
history targets; no additional large intermediate texture is needed.
At most two submissions are outstanding; a full queue skips incoming
source frames rather than accumulating work. Completion receipts are
published in submission order, after the native scope and vGPU frame
completion settle. This is speculative history on the GPU, not
independent parallel feedback computation.

If native asynchronous validation fails, dependent receipts reject and
the graph must drain and reset before accepting new work. Synchronous
pre-submission presentation failure preserves previous history.
Reset, resize to different dimensions, disposal and preview export
cannot race outstanding work. The preview invalidates epochs on seek,
drains the old queue, and reseeds before processing the new source.
Already submitted draws cannot be recalled; their stale completion
receipts are suppressed. Pause stops new submissions but allows
outstanding frames to finish. Consumers of the graph must drain and
read only the latest borrowed output before another render; earlier
receipts may identify ping-pong storage subsequently reused.

Reproduce (same environment as previous tests):

    pnpm build
    VIDEO_QUEUE=1 VIDEO_INPUT=copy xvfb-run -a -s '-screen 0 1440x900x24' pnpm test:video
    VIDEO_QUEUE=2 VIDEO_INPUT=copy xvfb-run -a -s '-screen 0 1440x900x24' pnpm test:video
    VIDEO_QUEUE=2 VIDEO_INPUT=external xvfb-run -a -s '-screen 0 1440x900x24' pnpm test:video
    pnpm test

Real NVIDIA Chrome/Vulkan 1080p30 VP9 three-second observations:
single queue 46 and 45 completed frames; two-frame copy 76, 76, 81;
two-frame external 76, 78. Thus approximately 25.3–27 fps versus
15–15.3 fps, not sustained source-rate playback. Observed outstanding
submission peak two (one for baseline), zero explicit GPU readbacks
or Canvas2D extraction during playback, one completion fence per
submission. The final two-frame runs also deliberately paused and
sought twice with both slots occupied, then exported the new seed
byte-identical to the earlier blue reference PNG. Zero browser/HTTP
errors and external requests. Existing image and direct texture
smokes passed, as did frozen install and build.

Actual Dawn Radeon and NVIDIA tests 4/4 each: existing image numerical
parity, two queued outputs compared bit-for-bit with serial outputs,
third submission rejected, reset/dispose blocked while outstanding,
and a native invalid row-stride write poisoning its dependent receipt
until reset. Subsequent reset seed matched the CPU oracle. The first
RED test failed and left its test process waiting due to test cleanup;
test cleanup now drains the outstanding promises and the abandoned
test child was stopped. No new dependency, native OBS change or
additional worktree. Single-frame mode remains default because
long-duration, 4K, device-loss recovery, arbitrary codec/color-space
parity and OBS interop remain unqualified.

## 2026-11-17 — Optional fused spatial/feedback pass

The next-video passes selector offers Split (reference, default) and
Fused (experimental), independently of queue depth and video input.
Fusion samples the spatial neighborhood and previous history in a
single WGSL pass. Seed frames use the existing spatial shader directly
on the history target. The graph no longer creates its full-resolution
spatial intermediate in fused mode (8,294,400 bytes of logical RGBA8
storage at 1920x1080, excluding implementation allocation overhead).
Actual browser encoder instrumentation confirmed two render passes
per submission including presentation, versus three in split mode.

The removed RGBA8 store/load is approximated with explicit WGSL
rounding. Do not claim bit identity: at exact half-byte ties both
tested adapters produced a one-byte difference from their native
render-target conversion. Explicit rounding, pack/unpack, and
bit-level conversion experiments did not establish exact equivalence.
The simple explicit rounding variant is retained as opt-in rather than
changing reference semantics or adding expensive emulation.

Native Dawn Radeon and NVIDIA suites passed 6/6 each. Across 480
successive fused frames per adapter (four dimension sequences,
including 1-pixel width, asymmetric fixtures, forced rounding ties,
two-frame submissions and resets), maximum difference from split
was one 8-bit RGB channel value; 258 channel comparisons differed
on each adapter, seed and alpha were exact. Native validation failure
poisoning/recovery passed for both split and fused. Chrome's actual
318x182 decoded VP9 source also matched within one channel value
for both fused input modes, including a fourth recurrence comparison
after an injected presentation failure. Exact source alpha remained.
No shader/device errors were reported in the successful probes.

Reproduce:

    pnpm build
    VIDEO_QUEUE=2 VIDEO_INPUT=copy VIDEO_FUSED=0 xvfb-run -a -s '-screen 0 1440x900x24' pnpm test:video
    VIDEO_QUEUE=2 VIDEO_INPUT=copy VIDEO_FUSED=1 xvfb-run -a -s '-screen 0 1440x900x24' pnpm test:video
    VIDEO_QUEUE=2 VIDEO_INPUT=external VIDEO_FUSED=1 xvfb-run -a -s '-screen 0 1440x900x24' pnpm test:video
    xvfb-run -a -s '-screen 0 1440x900x24' pnpm test:external
    pnpm test

Short 1080p30 VP9 browser observations on NVIDIA Turing: split-copy
63 and 80 completed frames in 3s; fused-copy 83 and 83; fused-external
80 and 82. Final repeat had 243 passes/81 submissions in split,
168/84 in fused-copy, 166/83 in fused-external. The latest throughput
was about 26.7, 27.7 and 27.3 fps respectively, so a modest gain in
that repeat, not a controlled benchmark or sustained 30fps claim.
All video runs passed pause, rapid seek at queue capacity, PNG reset
equality, zero explicit GPU readbacks/pixel extraction during playback,
no browser errors or external requests. Original image smoke,
native render/resize/compute probes, build and frozen install passed.

The default split/one-frame/copy behavior is unchanged. No native OBS
integration, dependency change, or remote publication. Long-duration
performance, other codecs/adapters, exact fused rounding, 4K and
device-loss recovery remain open.
