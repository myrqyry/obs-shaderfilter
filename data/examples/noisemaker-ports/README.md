# Noisemaker single-pass filters for OBS Shaderfilter

This directory ships **38 separate OBS-native .shader files** adapted from
[Noisemaker](https://github.com/noisefactorllc/noisemaker) by Noise Factor LLC,
which is licensed under MIT. Upstream source snapshot:
169ca24e6413c5fd2ced1a0787debe263887bb33 (main).

The original shaders/effects/filter/{name} program is linked in every
ported effect, along with copyright and MIT attribution. See
[NOISEMAKER-LICENSE.txt](NOISEMAKER-LICENSE.txt).

These are **single-pass OBS Shaderfilter filters** for an input video image.
They are not browser shaders, a JavaScript plugin, the Noisemaker shader
graph, its multi-pass effects, or its Polymorphic DSL.

## Shipped effects

| Family | Filter names (nm_ prefix, .shader extension) |
| --- | --- |
| Color and quantization | channel, chroma, colorReplace, invert, posterize, ridge, sine, smoothstep, step, threshold, tint |
| Edges and local lighting | deriv, edge, emboss, glowingEdge, sharpen, sobel |
| Optical effects | chromaticAberration, simpleAberration, prismaticAberration, lens, lensFlare, vignette |
| UV geometry and tiling | flipMirror, pixels, polar, repeat, scale, scroll, seamless, translate, tunnel |
| Procedural and temporal | clouds, craquelure, directionalBlur, patchwork, reverb, wind |

These 38 separate files complement the two existing printmaking effects in
../printmaking/ (ink hatching and jittered pointillism).

Open the Shaderfilter effect, choose the shader file, and adjust its
parameters directly in OBS. Filters that rely on source pixels require the
normal bound source image and should not be loaded as input-free sources.

## Compatibility choices

- Noisemaker's input sampler clamps to source edges. Shaderfilter's default
  sampler instead uses a transparent border. Each effect's nmSample helper
  clamps its UV to the last texel center. This prevents unwanted transparency
  at the edges of transformed or blurred opaque video.
- Noisemaker's tiled/global rendering coordinates collapse to OBS's complete
  filter frame through uv_size and uv_pixel_interval. Exact tiled export
  behavior is not part of these ports.
- Numeric control ranges and defaults come from Noisemaker's effect
  definitions wherever specified. A few source-internal render-scale
  values are fixed to 1 for OBS native-resolution rendering.
- Zero-width smoothing and zero-scale guardrails were added in the port.
- Noisemaker wind defines multiple build-time algorithms. This file contains
  **only the default Wind method**, with a cap of **32** image taps per
  pixel instead of Noisemaker's 128. Blast and Stagger are not implemented.
  This performance limit changes the longest trail appearance.
- Noisemaker lensFlare has multiple build-time lens families. This file
  contains only LENS_TYPE=0 (the upstream default).
- These effects are individual programs: their generic helper names may
  collide if concatenated into a single shader source.
- Some upstream color/mask effects intentionally output opaque pixels rather
  than carrying the source alpha. Other filters preserve their source alpha.
  The GPU smoke fixture below specifically tests opaque-source stability.

## Verified on Linux Mint / libobs 32

From the repository root:

    PYTHONDONTWRITEBYTECODE=1 xvfb-run -a python3 tests/verify_stdlib.py
    PYTHONDONTWRITEBYTECODE=1 xvfb-run -a python3 tests/verify_noisemaker_ports.py

The first command validates the shared stdlib and earlier printmaking effects.
The second builds the C++ libobs/OpenGL render probe, expands the real OBS
effect wrapper, creates actual textures, changes one control in each of the
38 filters, renders two 128x96 frames, and reads real GPU pixels back.
It requires each shader to visibly respond to that control and an opaque
input image to remain opaque at the tested settings. The test does not
use mocks, fixed expected image pixels, or snapshots standing in for output.

**Not established by these checks:** exact pixel equivalence against
Noisemaker's original WebGL2/WGSL output, 1080p/4K streaming performance,
Windows Direct3D compilation, or the appearance of every parameter
combination in a live OBS scene. Blur, clouds, convolutions and wind can
be meaningfully more expensive than simple color filters. Retest on the
intended GPU before putting these on a production live scene.

No runtime dependency on Noisemaker, a browser, or Node is required to
load or render these files in OBS Shaderfilter.
