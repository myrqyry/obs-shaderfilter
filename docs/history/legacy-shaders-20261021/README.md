# Older user-authored ShaderFilter sources — preserved originals

These four files were supplied as **older versions authored by the fork's
maintainer** on 2026-10-21. Their contents are archived **byte-for-byte**;
none are silently promoted over the newer `data/stdlib/` implementation.
This folder is not included in the plugin's installed shader data.

A fifth upload, `3d-panel.shader`, had exactly the same SHA-256 as
the existing tracked `data/examples/3d-panel.shader`
(`9e919b8a2c44a2e8be24644c0c5fd30d619147b46cd8be34e627eb2f639b03c5`).
We keep a single live copy instead of introducing an unnecessary duplicate.

## Execution contract

A normal `.shader` (including a file that `#include`s these helpers) is
passed between `effect_template_begin` and `effect_template_end` by
`obs-shaderfilter.c`. The wrapper supplies `image`, `textureSampler`,
`VertData`, `uv_size`, timing uniforms and the `Draw` technique. A complete
`.effect` normally selects **Override Entire Effect**, bypassing the wrapper
and requiring its own effect structure. Raw inline shader text still uses
the wrapper. The extension informs the UI's override setting; the
runtime setting determines whether wrapping happens.

The four archived files are **include libraries** with no `mainImage`.
They can compile when a host `.shader` includes their functions, but
they are not standalone runnable filters merely because they end in
`.shader`.

## Comparison with the modern standard library

| Older file | Modern equivalent and meaningful difference |
|---|---|
| `lib_color.shader` | `data/stdlib/colors.glsl` implements HSV, RGB/HSL, grayscale and a larger blend suite. Beware differing luminance conventions: the old file uses Rec. 709 coefficients, while `data/stdlib/math.glsl`'s `luma` uses Rec. 601. |
| `lib_math.shader` | `data/stdlib/noise.glsl` supplies hash and smooth noise, and `math.glsl` has guarded `remapUnclamped`. The older `map` divides by the input range without a zero-span guard; do not replace the newer helper with it. |
| `lib_spatial.shader` | `rotateUV` resembles `math.glsl`'s `rotateAround`. But old `fixAspect` scales X from UV origin while new `aspectCorrect` scales around 0.5: **not** numerically interchangeable. Old `zoomUV` provides pivoted scaling absent as a named new helper, but divides by zero when zoom=0. |
| `blending_modes.shader` | Modern `colors.glsl` provides many more named blend functions. The old file's **single integer-dispatched `blend(mode, base, layer)` API**, with specific HSL formula and layer-alpha behavior, is not present. Its semantics should be kept or deliberately re-specified before any modern port. |

No general equivalence is claimed: even similarly named blend modes may
differ at gamma, edge values, or alpha. This historical source is useful
for matching older authored shader aesthetics.

## Verification

`PYTHONDONTWRITEBYTECODE=1 python3 tests/verify_legacy_author_shaders.py`
compiles all four libraries **individually** under ShaderFilter's real
effect template, with synthetic `mainImage` functions that call actual
library symbols. It also performs an offscreen libobs/OpenGL pixel-readback
test on `data/examples/3d-panel.shader`. Neither isolated compilation nor
offscreen rendering proves interactive installed OBS UI behavior.

The existing panel deliberately has a transparent miss region and
opaque-alpha surface hits; the old file also samples the same image for
front and edge. These are facts about the historical code, **not**
automatically bugs to be rewritten without an intended visual reference.

Original source checksums:

```text
2b1f02e8a72806816e9615871c293e0a95848dcc42f2fd1b15384b1957b591e5  blending_modes.shader
90de7eaa78b3aeb39accf25cd53cb5d8053da359d3bdbacc4f128bbbc6bad584  lib_color.shader
e6c815acdf54053b5d7593e867eb82f74b4fafdad35a41b0509e1d4996b48219  lib_math.shader
0ccf0226816cffcbc0f90c448782afd1b9b64f22a59b37bb6a19a229fe565cdf  lib_spatial.shader
```
