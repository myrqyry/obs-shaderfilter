# Procedural printmaking filters for OBS Shaderfilter

Two OBS-native, single-pass shaders inspired by techniques in Noise Factor
LLC's [Noisemaker](https://github.com/noisefactorllc/noisemaker) effects.
These are HLSL-style shader files for OBS Shaderfilter, **not** GLSL shader
sources for Noisemaker's WebGL2/WebGPU render graph.

- **ink_hatching.shader** preserves the image's color and alpha while building
  up three angle-separated fields of fiber-like ink strokes, with additional
  layers in deeper shadows. Controls: ink strength, length, angle, tone balance
  and seed. Ink strength 0 passes the image through unchanged.
- **jittered_pointillism.shader** assigns each pixel to its nearest jittered
  cell center, samples the input image *at that center*, and prints a
  luminance-sized, antialiased dot over a user-selectable paper color. Controls:
  dot spacing, jitter, dot size, seed, paper color and opacity. Opacity 0 passes
  the image through unchanged.

Both require a valid input image; apply them to a source as a Shaderfilter
**filter**, not as a standalone source. They preserve the input alpha
unmodified, so transparent source areas remain transparent. Patterns use
absolute pixel coordinates derived from Shaderfilter's uv_size, so cells
remain square regardless of aspect ratio.

## Reuse

The shared primitives are in data/stdlib/printmaking.glsl. In a shader under
data/examples/myrqyry/printmaking/, use the relative include
../../../stdlib/printmaking.glsl. From a shader directly in data/examples/,
use ../stdlib/printmaking.glsl.

The helper functions printHash, printHash2, printValueNoise, printRotate,
printHatchField, and printNearestCell are composable building blocks. They do
not depend on the plugin's sampler; each filter decides how to sample an image.

## Original techniques, adaptation and credit

- Noisemaker
  [filter/hatch](https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/hatch):
  multi-angle, tone-gated, elongated noise strokes
- Noisemaker
  [filter/stipple](https://github.com/noisefactorllc/noisemaker/tree/main/shaders/effects/filter/stipple):
  nearest jittered cell centers, dot colors sampled at cell centers,
  darkness-dependent dot radius

This is a focused adaptation of those single-pass techniques, **not** a port of
their full six-mode Hatch/five-mode Stipple effects or Noisemaker's declarative
effect runtime. Their APIs, effect definitions, render graph, backends and
other modes are not embedded here.

Noisemaker copyright 2017-2026 Noise Factor LLC, MIT; see the
[retained license](NOISEMAKER-LICENSE.txt). No affiliation or endorsement is
implied. The files may contain material adapted from their shader routines
under those terms.

## Validation boundary

Run PYTHONDONTWRITEBYTECODE=1 xvfb-run -a python3 tests/verify_stdlib.py
in an environment with libobs headers and the OpenGL graphics backend.
It compiles both full filter examples through the real Shaderfilter wrapper
and include expansion, including their controls. Compilation does not
establish their pixel appearance, frame time at streaming resolution or
Direct3D runtime compatibility. Screen-space techniques will change their
grain size if the filter output resolution changes.

Approximate per-pixel work: ink hatching samples the input once and evaluates
three small four-corner value-noise fields; pointillism examines nine jittered
cells plus two image samples. No history buffers or external textures required.
