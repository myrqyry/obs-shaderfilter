# HyperShader Standard Library (OBS Shaderfilter)

Reusable HLSL-style utility headers for OBS Shaderfilter **user shaders**.
These are the five original user-authored headers, with small compatibility,
Worley-coordinate and runtime-loop safety fixes. Existing function names and
calls remain available.

| Header | Functionality | Needs |
|---|---|---|
| `math.glsl` | Constants, remapping, rotation, smoothing, 2D SDF helpers | None |
| `colors.glsl` | RGB/HSV/HSL/YUV/LAB, Photoshop-like blend modes, palettes, tone mapping | None |
| `noise.glsl` | Hash, value/gradient/simplex noise, cellular/Voronoi, FBM, curl and domain warping in 2D/3D | None |
| `animation.glsl` | Easing curves, procedural waveforms, time helpers | None |
| `printmaking.glsl` | Seeded procedural fibers, smooth noise, jittered Voronoi-cell helpers | None |
| `blur.glsl` | Gaussian, box, directional, radial and Kawase filters | `image`, `textureSampler` |
| `oklab.glsl` | Namespaced sRGB/linear/Oklab/Oklch conversions (SDR only; potatoFX adaptation) | None |

## Include paths are relative to the importing file

From `data/examples/example.shader`, include headers with `../stdlib/`:

```hlsl
#include "../stdlib/math.glsl"
#include "../stdlib/colors.glsl"
#include "../stdlib/noise.glsl"
#include "../stdlib/animation.glsl"
#include "../stdlib/blur.glsl"

float4 mainImage(VertData v_in) : TARGET {
    float4 original = image.Sample(textureSampler, v_in.uv);
    float3 toned = postProcess(original.rgb, 1.0, 2.2);
    float grain = 0.06 * (valueNoise(v_in.uv * uv_size * 0.03) - 0.5);
    float eased = easeInOutCubic(0.5);
    return float4(toned + grain * eased, original.a);
}
```

If the shader lives in `data/examples/psx/`, use `../../stdlib/` instead.
Shaderfilter recursively expands `#include "path"` relative to the file
containing the include and rejects circular includes. These are HLSL-style
headers for OBS's effect compiler, **not** standalone GLSL programs.

Constants `PI`, `TAU`, etc. are guarded against redefinition; headers can
be included together in any order. Keep generic function names in mind when
including third-party shader libraries with their own helpers.

## GPU work bounds and numerical behavior

- Blur limits: `boxBlur` radius 0..8 (up to 289 reads), 1D Gaussian
  0..16 offsets, directional/radial 1..32 total samples.
- Noise FBM/octave functions cap requested octaves to 0..8. Individual
  noise families can be expensive, especially nested 3D/domain-warp calls.
- Worley and Voronoi compute feature-cell distance in the correct global
  coordinate system. This changes previously incorrect results.
- Animation time helpers guard zero/negative durations; remapping guards
  zero-width input ranges.
- Math fallbacks: zero softClamp limit, out-of-domain bias/gain parameters,
  and zero modPositive period preserve their input; a negative modulo period
  uses its magnitude. aspectCorrect uses aspect ratio 1 when height is zero;
  expSmooth treats negative speed as zero.
- `blur.glsl` samples the default `image` texture and belongs in filters,
  or source shaders that explicitly bind a source image. Its loops are
  sampled per pixel; use conservative radii on streaming resolutions.

See `data/examples/fork/printmaking/README.md` for two single-pass printmaking filter examples and attribution.

## Reproducible validation

On a system with OBS/libobs development headers and graphics backend:

```sh
python3 tests/verify_stdlib.py
```

The test reproduces the plugin's effect wrapper/include expansion and
compiles each header and all headers combined using `gs_effect_create`
against the installed libobs/OpenGL compiler. Passing it establishes
successful compilation, **not** pixel correctness, 1080p/4K performance,
or compatibility across other graphics backends.

The standard library does not by itself introduce automatic Source→Filter
opacity/compositing or reorganize `.shader` filenames. Those remain separate
plugin/API decisions.

See `data/examples/fork/potatofx-ports/README.md` for the SDR palette port,
color-space caveats, and real GPU test coverage.
