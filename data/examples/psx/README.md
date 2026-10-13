# PSX-inspired OBS Shaderfilter pack

Four independently authored, **source-preserving** OBS Shaderfilter shaders based on PS1-era GPU characteristics. These are native OBS-compatible effect-language snippets (not GLSL / Godot shaders), each loaded using the plugin's **standard shader template**.

## Install and use

1. In OBS, select a **video source** (a game, image, camera, capture or scene). Right-click > **Filters**.
2. In **Effect Filters**, add **User-defined shader** from **obs-shaderfilter**.
3. Leave **Raw Shader Text** disabled and **Full Vertex Shader (.effect)** disabled.
4. In **Shader File**, browse to one of the four `.shader` files in this folder.
5. Hit **Reload effect** whenever you change the source file; adjust controls in the filter panel.
6. You can stack filters, but consider the GPU and order. Start with **one** filter. No extra pixels/expansion are required for normal use.

Paths on this Linux computer:
`~/loam/obs-shaderfilter/data/examples/psx/`.

| File | Purpose | Default look |
| --- | --- | --- |
| `psx_dither_quantize.shader` | Pure 4×4 ordered Bayer dither and 2–8 bits/channel RGB reduction | 5 bits, 75% dither, no other color grading |
| `psx_color_grade.shader` | Quantization plus gamma/contrast/saturation and screen-height color fog | Restrained, cool/hazy grade |
| `psx_instability.shader` | Source-space pixel-cell snapping, horizontal line jog, moving wobble and RGB-channel separation | Small animated image jitter |
| `psx_analog_hybrid.shader` | PSX color reduction/dither plus scanlines, chroma split, grain and *spatial* color smear | Soft PSX/analog crossover |

Each exposes a **Mix** slider: `0` bypasses the effect, `1` enables its full configured strength. These are deliberately separate filters; don't stack all four at full strength by default.

## Limitations / truth in labeling

- No direct access to 3D mesh vertices, perspective-correct UV data, real PS1 polygon warping, or camera depth. **Instability** deliberately imitates the *image-space impression* of low-resolution snap and imperfect analog signal behavior.
- **Color Grade** fog is based on source-image height, **not scene depth**. It works on normal camera and screen sources without a depth channel.
- **Analog Hybrid** spatial smear looks at nearby pixels **in the same frame**, not prior-frame feedback. It is not a true vidicon persistence/trail simulation. Temporal trails would need `previous_image` or `previous_output` and careful reset/resize handling.
- The shaders sample actual source images; they are not useful as standalone generators without a source image.
- They use the ordinary Shaderfilter default alpha handling (alpha-divided color) and keep output alpha in the two color-only filters. Distortion filters legitimately shift edge alpha when their image moves.
- Values are anchored to **source dimensions** via Shaderfilter's `uv_size`; the visual appearance can change with source scaling. No fake 3D geometry or external PSX plugin dependency.
- The effects are inspired by common PS1 rendering mechanisms, including the independent study of [wyvernbw/godot-psxlike](https://github.com/wyvernbw/godot-psxlike). They are **not a verbatim port** of that project's 3D spatial pipeline or a claim of PS1 hardware-accuracy.

## Verification

On this Linux Mint machine, the files compiled using the actual installed **libobs 32.0.1 OpenGL** effect compiler (standard wrapper + these shader bodies), then rendered into a 256×144 offscreen framebuffer under Xvfb/Mesa. A source gradient with transparent and semitransparent stripes was used. Each enabled shader produced a meaningfully different image from its own `Mix=0` pass; the two color filters kept alpha unchanged, and the instability and hybrid filters responded to advanced time. The test inspected framebuffer pixel readbacks.

Run the included smoke test from this directory:

```bash
./verify_psx.sh
```

`verify_psx.cpp` is the small native libobs/OpenGL fixture; it **reconstructs the standard shader wrapper** and is an effect-level compiler/render test, not a real OBS filter integration test. It writes optional RGBA pixel data if `PSX_CAPTURE_DIR=/some/folder` is defined. It does not alter your OBS profile, scenes, or installed plugin.

**Not yet verified:** the installed Shaderfilter plugin's actual filter lifecycle and property behavior inside OBS, other graphics backends/operating systems, high-resolution performance, or live camera/game capture quality. Start with one filter at native resolution; OBS's effect error text and logs are the authority if your installed copy differs.
