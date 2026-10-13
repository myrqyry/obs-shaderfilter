# RetroCapture GLSLP graph — isolated native GPU proof

Source: https://github.com/geldoronie/RetroCapture
Pinned revision: af76c6cb30688704c05ae2fef4feffb4ab3ce777
RetroCapture engine license: MIT. The bundled RetroArch shaders retain their own individual licenses.

**Purpose:** verify actual RetroArch-style multipass and frame-history behavior before exposing this to OBS. These experimental files do **not** change or install any OBS binary, add any OBS scene, or establish OBS Filter UI integration.

## Reproduce (Linux; no Docker or root)

Dependencies: git, C++17 compiler, pkg-config, GLFW3/OpenGL, libpng and xvfb-run.

    bash experiments/retrocapture-graph/run.sh

The runner clones the pinned RetroCapture source into a temporary sparse checkout, applies one reviewed experimental patch, builds the actual ShaderEngine, and renders four GPU tests. It redirects its app config/log directory to a temporary XDG directory and cleans up afterward.

Offline reuse of a preexisting *matching pinned-revision* source checkout:

    RETROCAPTURE_SOURCE_DIR=/path/to/RetroCapture bash experiments/retrocapture-graph/run.sh

Offline mode copies the necessary files into a temp directory and extracts the original committed ShaderEngine.cpp via git show. It cannot accidentally include working-tree source edits from the provided checkout.

## Verified receipts (October 13, 2026)

Mesa OpenGL llvmpipe, 160 × 120 synthetic input texture. Checksums are sums of GPU-read-back RGBA bytes.

| Input preset | Passes | GPU outputs | Evidence |
|---|---:|---|---|
| CRT BlurPi (crt/crt-blurPi.glslp) | 2 | 11,896,310 | Nonempty, varied output; actual multipass |
| Vector Glow (presets/vector-glow.glslp) | 9 | 12,353,239 | Real multi-Kawase glow chain |
| LCD response-time (motionblur/response-time.glslp) | 1 + history | 5,280,000 → 7,430,400 → 7,545,600 | Changed input after frame zero, then held fixed; history response evolves |
| Synthetic PassFeedback0Texture fixture | 1 + self-feedback | 8,400,890 → 10,157,236 → 11,036,831 | Source input unchanged all three frames, genuine feedback growth |

The tests use the original RetroCapture shader engine, a hidden GLFW context and real GPU readback. They do not mock shader output, and compilation alone does not satisfy the assertions.

## First-frame feedback bug and repair

The unmodified pinned engine created a new framebuffer for a shader declaring PassFeedback0Texture, which unbound the currently active pass's render target. On frame zero the shader drew into the default framebuffer; the actual pass output texture stayed empty. The test returned a zero checksum and black output for frame zero, even though later frames accumulated.

Our source patch, at patches/0001-restore-feedback-target.patch, initializes that new feedback texture to transparent black and restores the current pass framebuffer and viewport before drawing. This is a small patch applied to a temporary copy of the third-party source, **not** installed into any OBS plugin.

The same fixture now produces a varied, nonempty first frame and continues accumulating thereafter. This precisely distinguishes the fixed behavior from the original failure.

## Limitations that still matter

- The source engine's m_frameHistory path stores **processed output** instead of raw original input and performs its history copy using **pass 0's shader**, potentially applying it again rather than doing a neutral texture copy. Therefore the observed LCD response-time evolution does not establish precise RetroArch history parity. This needs separate correction and explicit input-history regression tests.
- The history ring-buffer resize check uses the remaining buffer's dimensions after popping the recycled element. That needs a resize test before relying on mixed resolutions.
- We have **not** proven output against native RetroArch reference images, actual OBS UI integration, live camera input, Windows Direct3D/Metal behavior, hardware GPU cost, resize/reload/reconnect handling, or color-space/alpha fidelity.
- A GLSLP preset is a graph: shaders plus intermediate buffers, pass sizes, aliases, float/sRGB flags and temporal inputs. It is not equivalent to a single ShaderFilter .shader or OBS .effect.
- RetroCapture runs GLSL on its own OpenGL context; ShaderFilter and HyperShaderFX use OBS's libobs graphics abstraction. Directly injecting foreign GL texture IDs into a normal OBS filter is neither generally portable nor safe.

## Sensible route into OBS

**First usable integration:** let a standalone RetroCapture process a real source and supply its rendered output to OBS through a carefully configured local video/media source or virtual camera. Verify that capture, streaming and source routing really work without exposing a server beyond loopback. Do not modify existing OBS scenes for the prototype.

**Long-term native implementation:** add an isolated OBS-native graph executor to a development filter, using libobs texrenders and OBS-compatible effect code. First prove two-pass native rendering and correct prior-frame ring buffers. Then add the supported subset of GLSLP preset parsing and explicit GLSL conversion or compatibility handling; do not claim arbitrary RetroArch shader imports without compilation and UI receipts.

ShaderFilter already offers previous_image/previous_output textures for one filter; HyperShaderFX offers iPreviousFrame for one effect; OBS Retro Effects has dedicated native multipass CRT/NTSC/bloom. None currently constitutes general RetroArch GLSLP import.

**Licensing:** RetroCapture engine is MIT but its bundled RetroArch shaders are not all MIT. The LCD response-time shader specifically declares GPL-2.0-or-later. We vendor only an independently authored tiny GLSL feedback fixture, test driver and minimal third-party engine repair patch, not the RetroArch shader library.
