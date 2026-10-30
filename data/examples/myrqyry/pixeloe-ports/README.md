# PixelOE Build 2 → OBS Shaderfilter

Source repository: <https://github.com/Koishi-Star/PixelOEwithC>
Inspected source revision: `2546d6e8b8c01be2ef18969bca034c919bdb11a2`.
The source project and its stated upstream, <https://github.com/KohakuBlueleaf/PixelOE>,
provide Apache License 2.0 notices. The upstream PixelOE license was also checked;
the license text is included in [LICENSE-APACHE-2.0.txt](LICENSE-APACHE-2.0.txt).

## Use

These are file-backed standard-wrapper `.shader` filters. The pixelize shader
now performs edge-aware bilateral denoising on each block sample **before**
contrast-pixel selection, so start with just this filter:

1. `pixeloe-pixelize.shader`

Select the file in its Shaderfilter filter and use **Reload Effect**. Keep
**Full Vertex Shader (.effect)** off. Set **Integrated Denoise** to `0` to
bypass it, or raise it toward `1` for stronger reduction. Increase **Denoise
Color Similarity** to smooth across larger color differences; increase
**Denoise Spatial Radius** to admit more neighboring pixels. Those stronger
settings can soften edges, so tune them against the bypass. The integrated
cross-shaped filter adds four texture samples for each pixel in a block. Its
default is intentionally strong (`Integrated Denoise = 1`, Color Similarity
`0.25`, Spatial Radius `1.25`); lower strength first if fine edges become too
soft.

The pixelizer also has optional **Color Quantization** (off by default),
**Color Levels per Channel** (2–32), and **Ordered Dither Strength** controls.
Quantization is applied to the selected, denoised block color; a fixed 4×4
Bayer threshold is shared across each output block so the dither does not
break up the pixel grid. Start with quantization `1`, 6–8 levels, and dither
strength around `0.4`; reduce dither if the pattern becomes too visible.

If the image looks better, but you still want PixelOE's contrast-aware outline
expansion, put `pixeloe-outline.shader` before `pixeloe-pixelize.shader`.
Use the same Pixel Size in both PixelOE filters. The separate
[`anime_bilateral_mean.shader`](../../mpv-anime-ports/anime_bilateral_mean.shader)
remains available for other chains, but stacking it before the integrated
denoiser will increase smoothing and GPU cost.

## Adaptation boundaries

- The two PixelOE shaders correspond to Build 2's sequential outline-expansion
  and contrast-pixel selection stages. The OBS filters are stacked to retain
  that same-frame ordering; `previous_output` is not used as a substitute for
  the source project's intermediate render texture. The existing bilateral
  denoiser remains available as a separate shader for other chains.
- UI controls replace the demo's keyboard controls. The demo's `showOriginal`
  switch is provided as **Show Original** in the pixelize stage. Integrated
  bilateral denoising runs on each block sample before its contrast tests;
  it is an OBS adaptation, not a separate full-resolution intermediate pass.
- The OBS versions preserve source alpha, unlike the source demo's processed
  paths, which output opaque alpha.
- The source's simplified luminance and per-channel morphology are retained in
  spirit. Texture edge behavior, coordinate conventions, GPU precision, and
  performance can differ from the GLFW/SDL demo. No visual parity claim is
  made until compared side by side.
- Both shaders are self-contained and use no includes, so the files can be
  loaded from a separate folder.

## Verification status

The files are checked through native libobs effect compilation and pixel
readback tests in this repository. Those tests demonstrate that the shaders
compile and respond to controls while preserving alpha; they do not establish
interactive OBS UI loading, two-filter scene integration, Windows/macOS
backends, full-resolution performance, or visual equivalence to PixelOE.
