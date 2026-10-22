# MPV anime processing filters for OBS Shaderfilter

Five standalone OBS Shaderfilter `.shader` ports/adaptations from the
[MPV Anime Build shader collection](https://github.com/Chinna95P/mpv-anime-build/tree/main/shaders).
All source code uses the existing single-pass Shaderfilter renderer. The MPV
`//!HOOK` syntax cannot be loaded directly in OBS Shaderfilter.

| File | Upstream source | Behavior |
| --- | --- | --- |
| `anime_line_thinner.shader` | `Anime-Line-Thinner.glsl` | Bright-neighbor morphological line thinning, adjustable threshold and mix |
| `anime_bilateral_mean.shader` | `Anime4K_Denoise_Bilateral_Mean.glsl` | Per-channel intensity/spatial Gaussian, 25 sample taps |
| `cas_luma_sharpen.shader` | `CAS-modern-1080.glsl` | Nine-sample AMD CAS-style luma sharpening |
| `static_luma_grain.shader` | `noise_static_luma.hook` | Static spatial luma noise |
| `static_chroma_grain.shader` | `noise_static_chroma.hook` | Static chroma noise approximated in RGB |

All 5 shaders preserve input alpha. Differences from mpv source:
- Original MPV `CAS-modern-1080.glsl` samples a dedicated LUMA plane.
  We compute Rec.601 luma from RGB and apply sharpened-luma differences to
  RGB, preserving the original pixel's color difference components.
- Bilateral Mean uses the upstream 5x5 kernel at default spatial sigma
  1.0. A configurable sigma adjusts weights within that fixed support.
  It preserves alpha rather than filtering alpha as upstream does.
- Luma and chroma noise use the source's static hash but adapt luma/chroma
  planes to RGB. Noise is intentionally static, not animated or film grain
  temporally re-randomized per frame.
- Pixel coordinates are per-frame OBS UVs, and sampling clamps to edge to
  match mpv's clamp sampler rather than OBS's border-black sampler.

Upstream licensing: MPV Anime Build is MIT by Chinna95P, and the Anime4K
bilateral implementation is MIT by bloc97 (2019-2021). Both original
attributions are retained; see `MPV-ANIME-LICENSE.txt`.

## Verification

From repository root:

```sh
PYTHONDONTWRITEBYTECODE=1 xvfb-run -a python3 tests/verify_mpv_anime_ports.py
```

This compiles the five actual files through the OBS Shaderfilter wrapper,
renders input textures with native libobs/OpenGL and reads pixels back.
Checks one changed control per effect, output RGB is nonzero, and opaque
input alpha remains opaque. These tests are **not** image-fidelity comparisons
against mpv, and do not establish real streaming frame rate or Direct3D
compatibility. 25 texture fetches per pixel can cost noticeable GPU time.
Neural network shaders and multi-pass Anime4K variants are deliberately
excluded; they require a real intermediate-texture render graph.
