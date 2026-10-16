# Motion Matte — native OBS Shaderfilter

**Motion Matte** is an independently implemented effect inspired by the
*MotionExtract* concept in Image/ine (ImWeb). Recovered from a local uninstalled
2026-10-13 draft and corrected/verified here. No proprietary Image/ine source
was imported, and this is not an Image/ine engine port.

Use **`motion_matte.shader` as a filter on an existing moving source** (webcam,
game capture, video), with Shaderfilter's normal `.shader` template, not Full
Effect mode. The shader explicitly declares and samples `previous_image`, the
plugin's **previous INPUT texture**, which it captures when that uniform is
present; it compares current vs previous RGB on the GPU.

## What you can do

- **Motion Matte:** grayscale movement mask, useful for downstream compositing
- **Moving Cutout:** unchanged straight RGB plus source alpha multiplied by
  the motion mask (stationary areas become transparent)
- **Motion Highlight:** overlay warm orange tint over moving regions
- Change motion sensitivity, threshold/feather, luma vs strongest-RGB
  difference, 5-tap blur in both frames, output mode, warmup suppression

The control `warmup_seconds` (default 0.1 s) suppresses false full-frame
movement at effect startup; it is not persistent motion tracking. This is
**two-frame differencing only**. Once someone stops moving, their stationary
pixels leave the mask. There is no running background model or trailing
history. Camera noise, compression and lighting flicker can cause detections.

The moving-cutout mode retains **straight-alpha** RGB: the Shaderfilter
standard wrapper handles alpha and compositing. The source's base opacity is
never increased. The motion-mask output retains original source alpha;
clients wanting an alpha matte should use Moving Cutout.

## Validation and caveats

`PYTHONDONTWRITEBYTECODE=1 xvfb-run -a python3 tests/verify_motion_matte.py`
compiles the actual expanded effect with installed libobs/OpenGL and reads GPU
pixels back from real current and previous textures. It asserts no false motion
on identical frames, mask on changed frames, threshold/sensitivity suppression,
first-frame warmup, source RGB identity and alpha behavior for cutout, plus
highlight and source-opacity preservation.

This does not establish installed OBS filter frame scheduling, exact Image/ine
parity, live 1080p/4K performance, or operation on Direct3D and Metal.
Previous-frame history can be uninitialized on the first frame and may reset
on source/size changes; don't disable warmup casually.
