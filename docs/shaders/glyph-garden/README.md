# Glyph Garden 🌸

An original standalone OBS ShaderFilter `.shader`, a playful sibling of
the maintainer's earlier `bitmap25` and Bitmap Glyph Motion. This is a
**separate effect**: neither original has been replaced.

**Source:** `data/examples/myrqyry/glyph-garden.shader`

## Six hand-drawn glyph families

Thirty newly drawn 5×5 bitmaps, in five tonal steps per family:
**Petal Garden, Starlight, Circuitry, Ink Strokes, Constellation, Toy Blocks**.
Their shapes are preserved as human-readable ASCII art immediately beside
their integer bitmasks in the shader source.

Use one family or **dual-family mode**: set A for shadows and set B
for highlights, with an adjustable split point and crossfade width.
The original `bitmap25` symbol sets live separately in Bitmap Glyph Motion.

## Actual grid spacing, not stretched glyphs

`Glyph_Pixels` defines the drawable square and `Gap_Pixels` adds an
**empty gutter** around it. Tile pitch is their sum; the 5×5 symbol stays
centered, sharp, and undistorted. The gap can be zero through 40 px.
Optional subtle grid lines and fixed 90° glyph turns add texture.

## Motion modes

The grid can be still or animate with **nine modes**:
horizontal drift; vertical drift; orbit; row wave; column wave;
checker dance; breeze rows; snapped stepping; parallax row bands.

Row/column motions are computed per complete band so they don't shear
individual glyphs. Checker dance shifts a glyph *inside* its cell,
bounded by half its gutter, and thus cannot stretch it. Wavelength,
speed, amplitude and snap cadence are adjustable. Orbit is the default.

## Ink and palette

Color choices include sampled original color, solid ink, duotone,
or three-color gradient ink; configurable backdrop and visible-source
strength; Normal, Multiply, Screen, Overlay, Soft Light, Hue, and Color
blends. The necessary blend formulas are built into the shader. It
has **no external includes or files**, including when opened from Downloads.

**Mix = 0** restores the exact original image. Source alpha is always
preserved, including partial transparency.

## Try these looks

- **Soft Garden:** Petal Garden + Starlight, 14px glyphs, 4px gap,
  Orbit, duotone ink (the defaults).
- **Circuit Quilt:** Circuitry + Toy Blocks, 9px glyphs, 3px gap,
  snapped steps, solid ink.
- **Ink Breeze:** Ink Strokes + Constellation, 20px glyphs, 10px gap,
  Breeze Rows, triad ink.
- **Quiet Print:** Petal Garden alone, 13px glyphs, 7px gap,
  Still, image-sampled color.

## Load into OBS

Add a **Shaderfilter Filter** to an image or video source and choose
`glyph-garden.shader` in the file picker. **Override Entire Effect OFF**.
The plugin supplies the normal `.shader` wrapper; this is **not** a
self-contained `.effect` file. Property sections are not collapsible.

## Evidence and limits

The tests were built specifically to avoid our earlier false-positive
"works in-repo but fails from Downloads" mistake:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tests/verify_glyph_garden_pixels.py
bash tests/verify-glyph-garden-plugin.sh
```

- Native readback copies only the shader into a detached Downloads-like
  folder, then exercises **50 GPU cases**, including all nine motion
  modes and both opaque and partially transparent inputs.
- The real-plugin test dynamically loads the installed ShaderFilter module,
  creates a `shader_filter`, loads the file with `from_file=true`, verifies
  controls and GPU readback, and checks actual spacing, dual-family tone
  changes, multiple motion patterns, unchanged gutters and preserved alpha.
- The existing 26-test Python suite and an out-of-tree native module build
  are separate regression gates.

These checks are not a substitute for a user opening the properties
inside a full interactive OBS scene. Windows/D3D, 1080p60 performance,
and all possible setting combinations remain unverified.
