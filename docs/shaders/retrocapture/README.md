# RetroCapture / RetroArch GLSL ports for OBS ShaderFilter

Source collection: https://github.com/geldoronie/RetroCapture
Inspected revision: `af76c6cb30688704c05ae2fef4feffb4ab3ce777`.
RetroCapture's *application* is MIT-licensed; its bundled shaders
have their OWN author/license metadata. Do not treat the entire library as MIT.

## CMYK four-screen halftone

`retrocapture_cmyk_print.shader` was adapted from:
`shaders/shaders_glsl/misc/cmyk-halftone-dot.glsl`.

That original file credits **Stefan Gustavson's GLSL/WebGL shader demo**
and **hunterk's RetroArch port**. Its own header explicitly declares the
shader **public domain** and states the MIT-licensed noise functions were
removed. This port keeps the four rotated C/M/Y/K dot screens and
the `sqrt(channel coverage)` threshold against cell distance.

**Differences from source:** aspect-correct dots measured per image height
rather than unit-square UV, fwidth-based dot-edge smoothing, live controls
for density/rotation/dot size/black ink/paper tint, source alpha preservation,
and black K dots composited as ink rather than the source's fallback to
original pixel color on K. This is a color screen-space printing *filter*,
not a physically calibrated printer/ICC color-management simulation.

The repo already has a DIFFERENT `data/examples/halftone.shader`, credited
to Tomek Augustyn / PixelBender, which outputs a monochrome dot screen.
This port does not overwrite or change that file.

### Use

Install/select `retrocapture_cmyk_print.shader` (in this repository:
`data/examples/retro_capture/retrocapture_cmyk_print.shader`) under the
standard ShaderFilter user-shader wrapper as a **file-backed filter on an
existing video/image source**. Keep **Full Vertex Shader (.effect)** off. A
standalone Shaderfilter Source has no input `image`, so it isn't suitable.
Start with Dot Density 52 and Effect Mix 1. For very dense screens,
the anti-aliasing control helps avoid moiré, but can blur dots.
Use Reload Effect after choosing the file.

### Native verification receipts

Using libobs 32.0.1 OpenGL and Mesa llvmpipe, constructed the effect with
the actual local ShaderFilter C wrapper and drew it into a 256×144 RGBA
render target. Staged real output pixels from a varied gradient/checker
source with partial alpha; no cached or simulated shader output.

| Case | Pixel checksum (sum of RGBA bytes) | Output present |
|---|---:|---|
| Effect Mix 0 | 22,351,440 | Yes, 36,864 pixels |
| Mix 1, density 52, rotation 0° | 20,956,159 | Yes, 36,864 pixels |
| Mix 1, density 18, rotation 25° | 21,229,791 | Yes, 36,864 pixels |

All cases compiled and rendered. The checksums differ for enabled and
changed settings. They do NOT prove exact visual parity with RetroArch.

**Outstanding:** actual installed OBS ShaderFilter UI/parameter control and
source/filter scheduling; alpha compositing against a real OBS background;
real GPU timing at 1080p/4K; other graphics backends.

## Additional shader findings (not ported)

- `vhs/ntsc-vcr.glslp`: six-pass composite/VCR/film chain with a texture
  resource. Rebuilding it as a single `.shader` would drop real NTSC passes.
- `presets/vector-glow.glslp`: nine passes including linearization,
  successive Kawase blurs, compositing and FXAA. A one-pass blur is not
  equivalent.
- `misc/glass.glsl`: simulated CRT glass reflection/convergence and
  **six previous-frame inputs** for color afterglow. Source header says
  public domain, but portions explicitly credit GPL material; review the
  combined derivation before redistributing an adapted file.
- `motionblur/shaders/response-time.glsl`: seven previous-frame inputs and
  response-time weighting; explicitly GPL-2.0-or-later. HyperShaderFX
  single feedback isn't an equivalent seven-frame input history.
- `motionblur/shaders/mix_frames_smart.glsl`: alternating-frame
  pattern detection across five previous-frame inputs. GPL-2.0-or-later.
- `procedural/knarkowicz-bokeh-parallax.glsl`: a five-layer animated
  floating bokeh field originally credited to knarkowicz / Shadertoy.
  Appealing as a standalone scene, but no explicit per-file license
  was established in the inspected file, so no derivative was copied.

The most transferable project-level lesson is RetroCapture's *preset
graph engine*: multi-pass GLSL pipeline, feedback and OriginalHistory
texture binding, parameter presets and source-frame routing. These are
host-level shader runtime features, not capabilities acquired by merely
dropping a GLSL file into ShaderFilter.
