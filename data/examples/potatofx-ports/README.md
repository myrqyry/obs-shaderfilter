# potatoFX perceptual palette for OBS Shaderfilter

A single **OBS-native** `.shader` inspired by Gimle Larpes' MIT-licensed
[potatoFX pPalettePosterize](https://github.com/GimleLarpes/potatoFX/blob/main/Shaders/pPalettePosterize.fx).
This is a selective **adaptation**, not a raw copy of the ReShade FX file.

## What looks different

The filter quantizes **Oklab lightness**, then builds Oklch hue/chroma
from a user-selected base color, rather than posterizing R/G/B channels
independently. It produces a coordinated set of colors even from
photographic input. The five modes are monochrome, analogous,
complementary, triadic (three bounded Oklch hue families), and full spectrum. Controls also expose:
2–16 **exact discrete lightness levels**, palette balance, 2x2 Bayer dithering, optional
highlight desaturation and effect mix. A 0 mix returns source pixels.

The self-contained single-pass effect lives at
`data/examples/potatofx-ports/palette_harmony.shader`; the limited
sRGB/Oklab helper is `data/stdlib/oklab.glsl`. Both are installed with
the existing plugin data directory. Source alpha is unchanged,
including partially and fully transparent texels.

## Color-space and fidelity contract

**SDR sRGB only.** This shader treats source RGB and the UI base
color as display-sRGB values and converts to linear RGB for Oklab.
The original ReShade shader chooses SDR, scRGB, HDR10/PQ or HLG
transforms from `BUFFER_COLOR_SPACE`. A standalone Shaderfilter
`.shader` does not inherit that ReShade metadata or its HDR transforms.
Thus the upstream HDR compatibility claim DOES NOT apply here.

We preserve the upstream palette/hue branch structure and Bayer pattern
but specialize it to SDR; also add source-alpha preservation,
a zero-mix passthrough, and input bounds. The RGB-only base-color picker is
interpreted as display-sRGB (upstream's direct `RGB_to_LCh` on the
picker assumes linear values). Exact image parity with ReShade is not
claimed. The output is limited to display-sRGB gamut.

No multipass graph, texture history, game depth, ReShade API, or
potatoFX `pCamera` / `pColors` / `pColorNoise` is imported.

Attribution: Gimle Larpes, © 2023, MIT. Original license text is in
`POTATOFX-LICENSE.txt`, kept with the port.

## Real GPU verification

From the repository root, on Linux with libobs development headers:

```sh
PYTHONDONTWRITEBYTECODE=1 xvfb-run -a python3 tests/verify_potatofx_palette.py
PYTHONDONTWRITEBYTECODE=1 xvfb-run -a python3 tests/verify_stdlib.py
```

This compiles the real OBS Shaderfilter effect wrapper, renders input
through libobs/OpenGL, and reads output pixels back. It verifies that
multiple palette controls visibly affect the result (including harmony
balance in complementary mode), that zero effect mix is pixel-identical
to input, and that alpha is preserved on opaque and mixed-transparency
fixtures. These tests do **not** prove exact ReShade image parity,
HDR correctness, Windows D3D parity, or live 1080p/4K frame performance.
