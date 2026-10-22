# myrqyry additions to OBS Shaderfilter

These effects are **not** part of the canonical
[exeldro/obs-shaderfilter examples](../README.md). Some are original to our
fork; other files are OBS/HLSL adaptations of externally authored shaders.
Preserve the per-file attribution and accompanying license notices.

## Standalone effects

- [Glyph Garden](../../../docs/shaders/glyph-garden/README.md)
  — original six-family 5×5 symbol mosaic with real tile gaps,
  nine motion modes, dual-family tone splits, and standalone verified rendering
- [Bitmap Glyph Motion](../../../docs/shaders/bitmap-glyph-motion/README.md)
  — rebuilt `bitmap25` 5x5 character mosaic, with 35 preserved glyph
  masks, intact-cell animation, self-contained HSL Color/Hue blend
  modes and native libobs real-plugin/pixel/alpha regression tests
- `bloom-karis.shader` — Karis-weighted bloom adaptation
- `mixwell-fluid-glass.shader` — fluid glass adaptation; license and detailed
  provenance under `docs/shaders/mixwell-fluid-glass/`
- `orphic_*.shader` — ORPHIC-based effects; see [ORPHIC-PORTS.md](ORPHIC-PORTS.md)
  for limitations and the AGPL-3.0-or-later notices on each derived file

## External ports and printmaking

- [Noisemaker ports](noisemaker-ports/README.md) — 38 effects from Noise Factor
  LLC's Noisemaker (MIT)
- [Printmaking](printmaking/README.md) — two adapted Noisemaker-inspired effects
  backed by `data/stdlib/printmaking.glsl` (MIT)
- [MPV anime ports](mpv-anime-ports/README.md) — five adaptations of MPV shaders
  (MIT, with per-file attributions)
- [potatoFX palette](potatofx-ports/README.md) — one Oklab palette harmony
  filter with its SDR-only color-space contract (MIT)

## Further myrqyry conversions and recovered effects

- [PSX image-space pack](psx/README.md) — four filters for dither, fog,
  instability and analog crossover (not a 3D console renderer)
- [URSC/N64](retro_ursc/RETRO-URSC-PORTS.md) — 3-point sampling and glimmer
  from the Godot shaders (MIT, with source license notes)
- [Shader Effects](shader_effects/SHADER-EFFECTS-PORTS.md) — engraving and
  Kuwahara-based watercolor (MIT, with source attribution)
- [RetroCapture CMYK](../../../docs/shaders/retrocapture/README.md) —
  four-screen print filter, original per-shader public-domain notice
- `composite_signal.shader` — one-pass Y/C separation, chroma delay and RF
  ghost artifacts; does not emulate a complete composite decoder
- `soft_register.shader` — two rotated, misregistered ink screens (Glyphfield
  adaptation; upstream MIT notice in GLYPHFIELD-LICENSE.txt)
- [Wind Drift Events](../../../docs/shaders/wind-drift-events/README.md)
  — animated petals, leaves, feathers; original MIT license preserved
- [ImWeb-inspired Motion Matte](imweb-ports/README.md) — **actual two-frame**
  movement detection and masking, not persistent temporal accumulation

The folder names represent **provenance**, not guarantees that the files are
identical to third-party renderers. Check the linked READMEs for GPU test
coverage, differences, unsupported features, and licensing.

After changing branches or upgrading the fork, reload effects in OBS. Old
absolute paths for these fork additions need to be reselected under
`data/examples/myrqyry/`; upstream examples at `data/examples/*.shader` or
`*.effect` are unchanged.
