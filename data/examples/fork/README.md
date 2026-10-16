# Additions maintained by our OBS Shaderfilter fork

These effects are **not** part of the canonical
[exeldro/obs-shaderfilter examples](../README.md). Some are original to our
fork; other files are OBS/HLSL adaptations of externally authored shaders.
Preserve the per-file attribution and accompanying license notices.

## Standalone effects

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

The folder names represent **provenance**, not guarantees that the files are
identical to third-party renderers. Check the linked READMEs for GPU test
coverage, differences, unsupported features, and licensing.

After changing branches or upgrading the fork, reload effects in OBS. Old
absolute paths for these fork additions need to be reselected under
`data/examples/fork/`; upstream examples at `data/examples/*.shader` or
`*.effect` are unchanged.
