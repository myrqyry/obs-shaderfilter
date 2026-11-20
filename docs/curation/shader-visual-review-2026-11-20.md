# Shaderfilter local library — visual review, 2026-11-20

Local assets under data/examples/myrqyry stay ignored, byte-for-byte
preserved, and excluded from fresh GitHub checkouts. This is **not an
authorship or redistribution approval**.

## Test method and limits

Wrapped 130 local shader/effect files in Shaderfilter's actual effect
template (including its relative includes); captured 320x192 real
libobs/OpenGL pixel output over a synthetic color-grid source.
125/130 produced an opaque frame. Generic harness failures:
escher-painting, psx/psx_analog_hybrid,
retro_ursc/ursc_n64_three_point, seigaiha-mandala,
simplicity-galaxy. Do not infer that these are broken inside the
full plugin. A real OBS filter/UI session and 1080p performance
were *not* tested.

The render contacts are locally saved under
~/loam/hyperShaderFX/.git/visual-review-fork-*.png.
Of the 130, 105 were formerly tracked and 25 additional local
candidates were present. No files were added back to Git.

## Real plugin follow-up

The installed Shaderfilter module was loaded in an isolated libobs/Xvfb
session with a synthetic OBS source. The ten candidates named in the
table below all compiled, exposed a parameter group, and changed actual
GPU-readback pixels: Bubbles, Mountain Silhouette, Lilac Lotus,
Flying Landscape, Weird Truchet Keyboard, Glyph Garden, Ink Hatching,
Jittered Pointillism, Soft Register, and Watercolor.

The focused check intentionally asserted only those three properties.
It did **not** establish alpha-preserving bypass, entire UI behavior,
1080p frame cost, correct optional controls, or shader licenses. The
test used the locally installed development binary, not a freshly built
release package.

## Distinctive looks and usable processing effects

| Candidate under data/examples/myrqyry | Visual reason | Provenance issue |
| --- | --- | --- |
| glyph-garden.shader | Intentional, highly readable 5x5 glyph mosaic | Header credits myrqyry + Aster as original |
| bubbles.shader | Pleasant overlapping translucent colored spheres | GLSL port without exact original link/license in header |
| mountain-silhouette.shader | Atmospheric sunset, layered mountains and clouds | Shadertoy-style port; exact origin unresolved |
| lilac-lotus.shader | Soft, luminous spiral flower | GLSL port; exact origin unresolved |
| flying-landscape.shader | Distinct blue/green fractal terrain | Shadertoy-style port; exact origin unresolved |
| weird-truchet-keyboard.shader | Bold geometric/typographic tunnel | Port; exact source author not identified |
| printmaking/ink_hatching.shader | Useful ink/engraving on camera input | Noisemaker MIT adaptation; notice present locally |
| printmaking/jittered_pointillism.shader | Strong halftone dot texture | Noisemaker MIT adaptation; notice present locally |
| soft_register.shader | Print-like misregistration, source-aware | Glyphfield MIT adaptation; notice present locally |
| shader_effects/se_watercolor.shader | Convincing pigment/brush texture | Shader Effects Inc MIT port and source revision documented |

The first six are strong *visual ideas*. The latter four are useful
*image-processing tools*, not necessarily background presets.

## Other collections

- 38 Noisemaker ports are mostly practical image operators. Crackling
  Craquelure, Clouds, Tunnel, Lens Flare and Posterize stand out; it
  would be better to curate a small utility set than expose all 38.
- Galaxy Nebula and Sparkly Tunnel are attractive but less distinctive
  starfields. RetroCapture CMYK Print is impressive but visually busy.
- Orphic Chladni is attractive but explicitly AGPL-3.0-or-later:
  resolve license compatibility before any redistribution.
- Black previews from audio, texture-history or other runtime-dependent
  shaders cannot be scored as poor aesthetics.

Animation comparison at t=1.25 and 3.75 seconds, mean absolute RGB:
Weird Truchet Keyboard 78.65, Bubbles 54.02, Lilac Lotus 26.38,
Flying Landscape 25.53, Mountain Silhouette 6.00. Glyph Garden's
default sampled settings produced no change, without exercising its
optional animation controls.

**No recommendation to re-track yet.** Locate the exact upstream
source/license for every port, preserve notices, run through the
actual Shaderfilter plugin with native controls and representative
frames, then approve only specific selected files.
