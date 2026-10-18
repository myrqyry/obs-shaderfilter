# Shader Effects WebGPU → OBS ShaderFilter

Source: https://github.com/shader-effects-inc/shaders
Inspected commit: 81fd4ece5d493ca6c424a2af41f0e2c361ec8258 (2026-10-13).
Copyright © 2026 Shader Effects Inc. Source engine/components: MIT.
Commercial design editor, premium presets, and platform features have separate terms; none were copied.

These .shader files are **file-backed, standard-wrapper ShaderFilter filters** for existing video/image sources. Disable "Full Vertex Shader (.effect)" in OBS. They need the input image texture and are not no-input standalone generators. Install into the plugin's data/examples/myrqyry/shader_effects directory, attach a ShaderFilter filter to a video/image source, select the file and Reload Effect.

## Conversion ledger

| File | Original component and mechanism | Behavioral/fidelity boundary |
|---|---|---|
| se_engraving.shader | Engraving/index.ts, std/effects/stylize.ts — luminance-to-cosine-threshold engraving with brightness-driven phase relief. Includes line, three-angle crosshatch (8°, +72°, −38°) and continuous Archimedean spiral plate. | The source's shader noise primitive is replaced by explicit smooth value noise. This is actual screen-space input-image filtering, not SVG vector conversion, real geometry, or exact numerical WGSL equivalence. Styles are an integer UI selection. |
| se_watercolor.shader | Watercolor/index.ts, std/effects/stylize.ts, gpu/kit/stylizePaints.ts — four overlapping Kuwahara neighborhoods, selecting the lowest RGB variance, plus slow UV bleed and paper grain. | Uses the ShaderFilter source texture instead of framework RTT. Default radius 3 selects 2×2 taps in four quadrants (16 samples). Radius 8 selects 5×5 in four quadrants (100 samples per pixel): expensive. Original helper noise is replaced by smooth value noise. No claim of perfect visual parity. |

### Alpha handling

The normal ShaderFilter path uses DrawAlphaDivide, so user shader code receives **straight-alpha** input colors. Engraving preserves source alpha and uses straight RGB. Watercolor premultiplies each tap for the variance test and unpremultiplies the selected mean once for painted color. Do not enable USE_PM_ALPHA without reworking these paths.

## Native test receipts

Compiled through native **libobs 32.0.1 OpenGL** with the actual ShaderFilter standard effect wrapper assembled from this checkout, then rendered with Mesa llvmpipe at 256×144 against a nonuniform checker/gradient source with a partially transparent region.

| Effect / case | Pixel checksum | Visible pixels |
|---|---:|---:|
| Engraving bypass, Effect_Mix = 0 | 22,351,440 | 36,864 |
| Engraving crosshatch, Mix = 1, frequency 90 | 19,889,400 | 36,864 |
| Engraving spiral, Mix = 1, frequency 50 | 22,181,171 | 36,864 |
| Watercolor bypass, Effect_Mix = 0 | 22,351,440 | 36,864 |
| Watercolor brush radius 3, Mix = 1 | 19,699,233 | 36,864 |
| Watercolor brush radius 6, Mix = 1 | 19,674,965 | 36,864 |

All six cases compiled and rendered. Bypass differs from enabled states, and changing meaningful settings changes the rendered output.

**Not yet verified:** actual installed-plugin Filter UI loading, slider/color-picker binding, native resolution and GPU performance on target graphics hardware, macOS/Windows backends, visual parity with WebGPU, or complete UI alpha/compositing behavior.

## Other candidates and non-portability boundaries

- TimeTrail and DataMosh are **compute-based ping-pong temporal algorithms** with source-frame history and state reset. They are not faithful one-pass ShaderFilter conversions. HyperShaderFX's iPreviousFrame requires independent testing for a compressed state/display adaptation.
- PixelSort is a **persistent odd-even sort over source-coordinate state**, not an image-space brightness band trick. A screen-space fake misrepresents the source; our tree already contains separate PixelSort work.
- CompressionArtifacts uses a JPEG-inspired **8×8 DCT coefficient quantization compute pass**, an RGBA16F cell texture, and a display stage. Existing PSX artifact effects are not equivalent.
- ThinFilm uses analytic 3D shape gradient/normal information; a screen-space rainbow rim would be a distinct stylization.
- LightLeak is promising but HyperShaderFX already has another light leak effect (noisemaker_light_leak.effect). Compare mechanisms before duplicating.

## Original MIT license notice

MIT License

Copyright (c) 2026 Shader Effects Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
