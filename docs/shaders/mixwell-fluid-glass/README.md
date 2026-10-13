# Mixwell Fluid Glass — OBS Shaderfilter

**File:** `data/examples/mixwell-fluid-glass.shader`

A fluid-brush refraction effect adapted from the Mixwell Reverse-Drift
Function (RDF) published by Doug L. James and Ethan James. It is a
**source-image deformation**, not a particle simulation, volumetric fog,
or a background generator.

Mixwell paper/source: https://github.com/dougjam/mixwell-2026

The original Mixwell code is MIT-licensed, copyright (c) 2026
Doug L. James and Ethan James. The complete upstream license is preserved
in this documentation directory as `LICENSE-MIXWELL-MIT.txt`.

## Use in OBS

1. Add **User-defined shader** to a source or scene under OBS Filters.
2. In the **Shader Source** section, use the shader-file picker (the fork
   defaults to a file; disable **Raw Shader Text** if that switch is on).
3. Select `mixwell-fluid-glass.shader` from this worktree's
   `data/examples/` directory.
   The companion guide/license are under `docs/shaders/mixwell-fluid-glass/`
   and intentionally NOT in the examples folder. OBS parses Markdown
   headings as shader preprocessor commands if the wrong file is selected.
4. **Do not enable Entire Effect**. This is a normal Shaderfilter
   `.shader` using the plugin's built-in image, sampler, UV and clock.
5. Begin with Strength around 0.2, Speed around 0.15, and Fast quality.
   For a static visual, set Speed to 0.
6. Select **One** brush for the lowest GPU cost. Higher radius and
   stroke length affect a larger portion of the source.

This adds a file-based shader only. No existing OBS filter, scene,
installation or plugin binary is changed automatically.

## Controls

- Strength [0–1]; 0 returns the unmodified sampled source exactly.
- Brush radius [0.012–0.160] in normalized image-height coordinates.
- Stroke length [0.08–0.90] controls how far the fluid brush travels.
- Drift speed [-2–2] animates its strokes from Shaderfilter elapsed_time.
- Center X/Y [0–1] positions the local two-stroke composition.
- Direction [-180–180 degrees] rotates the fluid strokes.
- Brush strokes: One or Two.
- Quality: Fast (8 midpoint integration steps per stroke; default)
  or Detailed (16 steps per stroke).

### Technical mechanism

`fluidGlassBrushVelocity` evaluates Mixwell's softened 2D influence
matrix `K(v,r)=A*I+B*v*v^T`. `fluidGlassReverseBrush` integrates
backward from the end of a moving brush with explicit midpoint steps.
Points beyond four brush radii from the path are skipped; a smooth mask
reduces boundary discontinuities. The image texture is sampled **once**
after composing the inverse brush mappings.

The influence matrix and integration are derived from Mixwell's
MIT-licensed `public/code/glsl/MixwellBrush.glsl`. Our real-time
implementation uses bounded **fixed steps**, instead of the adaptive
midpoint integrator described by the authors; the output is therefore
an approximation, **not** a faithful port of Mixwell's entire solver.

This is separate from the fork's original ripple and swirl effects:
it uses spatially localized, physically motivated inverse mappings
rather than simply adding sinusoidal offsets to image UVs.

### Limitations / cost

At Detailed quality with two brushes, a pixel lying within both brush
regions performs at most 32 midpoint steps, each evaluating the Mixwell
brush matrix twice. Cost is significant for 1080p60 / 4K sources.
Begin with Fast/One and check OBS rendering performance before enabling
higher quality during a live stream. No frame history or intermediate
resampling buffer is needed.

Source alpha comes from the source sample at inverse-mapped coordinates.
The UVs are clamped at edges to prevent unintended transparent borders.
This shader does not synthesize extra haze or colors by itself.

## Verification

- Verified through **real libobs 32.0.1 native OpenGL shader compilation and
  offscreen GPU pixel readback** under Linux Mint, Mesa llvmpipe. Reproduce
  using `xvfb-run -a python3 tests/verify_mixwell_fluid_glass.py` on headless
  Linux (requires a C compiler, pkg-config, libobs headers and OpenGL).
  An existing graphical session can also run the Python test directly.
  The test assembles Shaderfilter's actual standard template and applies its
  OpenGL-specific stripping of `[loop]` before `gs_effect_create`.
- At 256×144, a nonuniform gradient/checkerboard input with partial alpha
  renders correctly with Strength 0. Strength 0.65 alters 21,599 pixels,
  and changing Direction from 0° to 90° alters 22,093 pixels. At the same
  strength/direction, 8→16 quality steps changes 4,300 pixels, and two→one
  brush strokes changes 19,291 pixels (RGB comparisons on llvmpipe, keeping
  image and time unchanged). The test checks variation and coverage rather
  than relying on fixed driver-specific checksums.
- An earlier revision used `static const float FLUID_GLASS_PI` for its
  degrees-to-radians conversion. libobs/OpenGL warned it was uninitialized,
  and nonzero strength produced a flat RGBA `(0,0,0,32)` frame in our test.
  The preprocessor constant and these rendered-pixel assertions fix and
  guard that exact regression, which compile-only validation missed.
- The source and tests retain separate Fast (8 midpoint steps) and Detailed
  (16 steps), one/two stroke bounds, and neutral-source bypass checks.

**Still unverified:** loading/rendering through the installed ShaderFilter
Filter UI, actual audio/interaction (not applicable to this shader), target
GPU frame cost at 1080p60/4K, source-edge behavior on production inputs,
Windows/macOS shader-backend parity, and live OBS compositing/alpha behavior.
Passing a direct libobs readback does **not** verify the installed plugin's
source/filter scheduling and properties lifecycle.

The shader is committed on the separate
`aster/mixwell-fluid-glass` branch/worktree to protect parallel changes
in the normal OBS repository.
