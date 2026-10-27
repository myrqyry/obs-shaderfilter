# Curated OBS Shaderfilter ports

## Curated shader ports (standalone filter mode)

Real World Shader originals by Jan Kohlbach, MIT; license at
[REAL-WORLD-SHADER-LICENSE.txt](REAL-WORLD-SHADER-LICENSE.txt).
Real World Shader effects are conceptual adaptations, not pixel-identical ports.
The HyperShaderFX entries were adapted from our existing local full effects;
the SZION entries were adapted from our existing WGSL filter implementations.
All effects expect a video/image input and must be loaded with **Override
Entire Effect off**. Their sliders change the actual distortion,
noise, illumination or chroma instead of mixing the whole final image.

- `rw_radial_fold.shader` — directional collapse / rotating radical fold
- `rw_micro_noise_displace.shader` — pixel-granularity coordinate scrambling
- `rw_organic_melt.shader` — animated organic noise flow
- `hf_focus_noise.shader` — adjustable clean-zone noise
- `hf_focus_bulge.shader` — adjustable lens-like bulge and pinch
- `hf_interactive_rgb_shift.shader` — position-controlled channel offsets
- `hf_optical_halation.shader` — soft high-luminance scatter
- `sz_liquid_warp.shader` — SZION moving layered wave distortion
- `sz_chroma_mosh.shader` — SZION spatial chroma displacement without luma movement

These are standalone, self-contained files; nothing is loaded from sibling
modules or a remote server. `sz_chroma_mosh.shader` does not reproduce a true
codec datamosh, nor SZION's complete parameter and sampling repertoire.
See `tests/test_curated_shader_ports.py` and the native GPU test results
before inferring coverage on other OBS backends.

## Neutral values of actual effect parameters

No global Mix slider. The following controls alter the effect's geometry,
pixel displacements, noise, light contribution or chroma strength. Set the
listed parameter to 0 to restore the original input.

| Shader | Neutral parameter |
|---|---|
| `rw_radial_fold.shader` | `Fold_Strength = 0` |
| `rw_micro_noise_displace.shader` | `Distortion = 0` |
| `rw_organic_melt.shader` | `Displacement = 0` |
| `hf_focus_noise.shader` | `Noise_Strength = 0` |
| `hf_focus_bulge.shader` | `Strength = 0` |
| `hf_interactive_rgb_shift.shader` | `Shift = 0` |
| `hf_optical_halation.shader` | `Intensity = 0` |
| `sz_liquid_warp.shader` | `Amount = 0` |
| `sz_chroma_mosh.shader` | `Color_Mix = 0` |

## Running and validating

Use **Shaderfilter Filter**, **from file**, and leave **Override Entire Effect**
**off**. The shader file can be selected directly from this directory; no
extra includes or textures are required. No generic output-opacity slider
is added. Every shader preserves the original alpha; to disable the effect
without disabling the OBS filter, set its own neutral control to zero.

The included tests use `python3 tests/test_curated_shader_ports.py` for
portable contracts and `python3 tests/verify_curated_shader_ports.py`
for actual libobs shader compilation and offscreen plugin rendering with a
source texture. The GPU tests need an installed Shaderfilter plugin,
libobs development headers, C/C++, Xvfb and a working Mesa/OpenGL environment.

Source distinctions:
- `rw_*`: inspired by Jan Kohlbach's source GLSL but not exact UI/mouse
  parity (especially the intentionally unusual `atan(x, x)` radial fold).
- `hf_*`: adapted from our existing HyperShaderFX OBS full-effects and given
  Shaderfilter-native parameter controls.
- `sz_*`: originally WGSL in SZION, rewritten for OBS/HLSL. Chroma Mosh
  moves chroma **spatially**; it does not recover codec motion vectors or
  temporal frame history. It draws on SZION's GLEECH-inspired implementation
  (Pixhell42/GLEECH, MIT).
- The native tests demonstrate Linux Mesa/OpenGL offscreen behavior, not
  Windows Direct3D compilation, a real OBS GUI session, or exact visual
  parity with original WebGL / HyperShaderFX / SZION renderers.

### Licensing

The Real World Shader source is MIT licensed: Jan Kohlbach (2026).
See [REAL-WORLD-SHADER-LICENSE.txt](REAL-WORLD-SHADER-LICENSE.txt). Our
HyperShaderFX and SZION adaptations preserve project/source credit in each
file. Keep associated upstream attributions when redistributing them.
