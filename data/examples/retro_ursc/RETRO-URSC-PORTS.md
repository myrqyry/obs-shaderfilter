# Ultimate Retro Shader Collection → OBS ShaderFilter

Original project: https://github.com/Zorochase/ultimate-retro-shader-collection

Inspected revision: `8cd971d0a275ef126151a99adf49cae1a64614c4` (2026-10-13). Creator: Zorochase. The original shaders target **Godot 4**, and most are `spatial` materials. The following conversions target **OBS ShaderFilter's standard .shader wrapper in file-backed mode, on an existing video/image capture source**. They are not Godot source files, and cannot access scene vertices, UV topology, mesh normals, camera depth or original mipmaps.

| Port | Original mechanism | Explicitly changed / omitted |
|---|---|---|
| `ursc_n64_three_point.shader` | The three-corner triangle interpolation of `shaders/ursc/spatial/utilities.gdshaderinc`'s `texture_filtered` | Performs 3-point filtering on a user-selected **virtual, screen-space sampling grid**, not on each mesh's source `albedo_texture` UVs. Uses nearest neighbor samples, preserving the original 3-point interpolation weights. It cannot correct perspective-incorrect UVs or simulate per-vertex texture LOD/fog. |
| `ursc_shiny_glimmer.shader` | Nearest-step brightness adjustment from `glimmer()` inside the SHINY path of `shaders/ursc/spatial/common.gdshaderinc` | Applies that adjustment to already-rendered RGB pixels rather than normal-derived specular/light intensity. Preserves relative channel proportions but does **not** recreate the original Shiny material's lighting, reflected direction or shadow model. |

Both shaders offer user controls and a true `Effect_Mix = 0` bypass; neither requires audio, previous-frame state or HyperShaderFX.

## Verification receipts

- Compiler: native **libobs 32.0.1 OpenGL** effect compile, using the installed ShaderFilter checkout's actual standard wrapper. Mesa llvmpipe GPU execution at 256×144, with a nonuniform synthetic checker/gradient RGBA source (including partially transparent pixels).
- N64 3-point: mix 0 checksum **22351440**, effect on at 320×240 virtual grid checksum **22295631**, at 48×36 checksum **22216723**.
- Glimmer: mix 0 checksum **22351440**, effect on at 16 brightness steps checksum **22336950**, at 8 steps checksum **22350422**.
- All six runs compiled and rendered with 36,864 visible pixels; output differed when the relevant control changed. No black/empty frames in this harness.
- Missing: real installed-plugin Source/Filter UI smoke tests, alpha-perfect pixel-level comparison to a Godot reference, performance on target GPU, Windows/macOS backend tests. ShaderFilter Source mode has no input image: these are **filters to attach to existing video/image sources**, not generators.

The `data/examples/psx` directory contained **preexisting concurrent work** when these ports were added. Nothing in that directory was modified as part of these two conversions.

## Original license and attribution

MIT License

Copyright (c) 2024-2026 Zorochase

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

URSC acknowledges that its three-point filtering derives from MenacingMecha's Godot N64 work and its SHINY shaders from Zacksly's PSX Pickup Shader. Consult the source repository's README and upstream works for their detailed attribution.
