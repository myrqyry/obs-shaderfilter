# Bitmap Glyph Motion — recovered and rebuilt

`data/examples/myrqyry/bitmap-glyph-motion.shader` is a **new,
opt-in** image filter, reimagining the maintainer's older,
locally authored `bitmap25.shader` (SHA-256
`8448a979ccd6c804ec0f8541974631c3068c0be95077f4c8c2cc23803c0128a5`).
The older source remains intact; no user OBS scene has been modified.
The entire original **seven sets × five intensity levels** of 5×5
integer glyph bitmasks was carried across, with a checksum regression
to prevent unintentional glyph-art changes.

This is a **selective redesign**, not a backward-compatible
implementation of every setting in the old 1,061-line shader.

## Changes and why they matter

- **Whole-glyph motion:** Transform the *grid origin* before cell
  lookup, then quantize and draw the 5×5 glyph within that translated
  square. The glyph is not stretched by separate nonlinear transforms
  for image sampling and drawing. `Motion_Mode` selects flow or
  circular/orbital translation of the entire grid; `Animate` is
  off by default.
- **Proper Hue and Color blending:** Includes the maintained
  `data/stdlib/colors.glsl` and calls `blendHue` and `blendColor`
  rather than the old shader's direct RGB-channel swapping. Normal,
  Multiply, Screen, Overlay and Soft Light are also available.
- **Alpha preservation:** Applies the stylization in RGB only and
  restores the input's **exact source alpha**. `Mix=0` is direct
  passthrough, including semi-transparent sources.
- **Safe numeric boundaries:** Glyph cell size is clamped to 5 px;
  tone window is clamped against a zero-length range; user opacity
  and interpolation factors are saturated. Avoids a divide by zero
  when thresholds are equal.
- **Smaller controls:** Seven blend choices (instead of the
  older shader's 17), three color modes (sampled ink, solid ink,
  duotone), brightness thresholds, cell size, glyph set and simple
  motion controls. Deliberately omits the old palette library,
  orbit-per-glyph simulation and complex easing presets for now.

## Use in OBS

Add **Shaderfilter Filter** to a source and select the **file**
`data/examples/myrqyry/bitmap-glyph-motion.shader`, then keep the
default **Override Entire Effect = false**. This is a `.shader`,
not a self-contained `.effect`: ShaderFilter supplies `image`,
`textureSampler`, `VertData`, `uv_size`, `elapsed_time` and the
Draw technique through its normal effect wrapper.

Try `Ink_Mode=2` (duotone), `Blend_Mode=0`, `Cell_Pixels=10` or
`16`, `Background_Amount=0.1`, then enable `Animate` if desired.
`Blend_Mode=5` and `6` expose proper Color and Hue transfer.
Groups in the OBS property sheet **are not collapsible**.

The filter's source alpha always passes through unchanged. It is an
image-processing filter, not an independent procedural generator.

## Verification and boundaries

Test with:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tests/verify_bitmap_glyph_motion.py
```

The repeatable suite uses the real project `.shader` wrapper and
reads **actual pixels** through native libobs/OpenGL (NVIDIA
RTX 2070 Super, libobs 32.0.1). It checks ten control transitions
against both opaque and partial-alpha input (20 cases), including
distinct Hue-vs-Color blend output, animation time and motion mode.
It also verifies exact preservation of the original 35 glyph masks.

It does **not** establish: an interactive installed OBS UI run,
1080p60/4K performance, Windows/D3D backend parity, frame-to-frame
flicker freedom at different resolutions, or complete semantic
equivalence to all historical shader options.

Unlike the original, this effect intentionally samples one image
color per glyph cell and uses that representative color for the
glyph mask. This may give a different look in fine detail; keep
the original `bitmap25.shader` available for visual comparison.
