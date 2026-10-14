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
