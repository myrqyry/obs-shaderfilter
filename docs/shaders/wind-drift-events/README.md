# Wind Drift Events — OBS Shaderfilter

A lightweight, stateless **petal / leaf / feather** effect for stream alerts, transitions and atmosphere.

Loadable shader: `data/examples/myrqyry/wind-drift-events.shader`

The shader is its own 2D analytic implementation, inspired by the wind, gust, per-particle tumbling and vortex ideas in [Profesor Shader's Godot example](https://github.com/profesorshader/shader-wind-driven-falling-leaves-petals-feathers) (MIT, copyright 2026 Profesor Shader). The upstream license is preserved as `LICENSE-MIT.txt` beside this guide. It does **not** port Godot's GPU particle state machinery or 3D renderer.

## Use as an alert overlay — recommended

1. Add an **Image Source** to OBS, selecting the included **`transparent-1920x1080.png`**. It contains transparent pixels, not a static picture. Scale it to your canvas if needed.
2. Add a **User-defined shader** filter to that image source. Select **`wind-drift-events.shader`**. Leave **Full Vertex Shader / Entire Effect** **OFF**.
3. Keep the source/scene item visible. Choose **Burst on enable** and leave the shader filter disabled between alerts. Enable the **filter** to trigger a new burst; disable/re-enable it for subsequent alerts.
4. In OBS hotkeys or your stream-event automation, toggle the filter's enabled state. If your automation toggles the entire source's visibility instead, prefer a custom source activation test first: visibility does not necessarily reset the filter's `elapsed_time_enable` timer.
5. Set Shape, Amount, Size, wind and tint. The default 12 particles and max 24 are conservative for a live stream.
6. For continuous floating particles, change Playback to **Continuous** and leave the filter enabled.

The plugin also offers **Shader Source** (a standalone generative source), if you want a full-screen overlay without an image source. Set its width/height to your canvas and enable **Transparent overlay only**. Its burst restart behavior with scene visibility has *not* been verified; the filter-enable workflow above is the supported trigger concept.

### Applying directly to a camera or video source

The **Transparent overlay only** checkbox defaults **OFF**. In this mode the shader composites particles over the original image rather than replacing it with transparent pixels. Keep that setting when filtering a webcam. For an independent overlay you can toggle the checkbox ON; transparent particles require transparent-capable compositing of the parent source.

## Parameters

- **Playback:** finite burst on filter-enable or continuous drifting.
- **Shape:** pink sakura-like petals, amber leaves, or ivory feathers.
- **Particle count:** 1–24; **12** by default. Each output pixel evaluates at most 24 candidates; count affects GPU load.
- **Particle size:** normalized by canvas height (default 0.016).
- **Fall speed:** changes downward progression; positive range 0.1–2.
- **Wind direction/force:** angled cumulative drift.
- **Gust variation:** periodic nonuniform displacement, integrated relative to the spawn point.
- **Swirl:** curved lateral motion.
- **Tumbling:** individual angles and foreshortening produce fluttering depth cues.
- **Burst duration:** approximate particle lifetime, 1–15 seconds; individual lifetimes vary. New particles spawn during the first ~0.8 seconds.
- **Opacity**, **Color tint**, **Arrangement seed**.
- **Transparent overlay only:** OFF by default to preserve the camera. ON outputs premultiplied RGBA without sampling the original image.

A shader parameter can be animated or set externally through whatever filter-control automation is available in OBS. This implementation does *not* include an OBS WebSocket bridge, follow/subscribe detection, or external alert binding.

## Architecture and boundaries

The HLSL-style shader uses a single `mainImage` function inside Shaderfilter's existing OBS effect template. Each particle derives initial attributes deterministically from its index and seed. Positions, wind, initial phase, tumble and silhouette are recomputed from the plugin's time uniform; there is no simulation buffer or persistent particle state.

In **Burst** mode, the shader reads `elapsed_time_enable`, which is reset in Shaderfilter's `shader_filter_tick` when a filter transitions from disabled to enabled. In **Continuous** mode it reads `elapsed_time`. All loops have a fixed upper bound of 24. The three silhouette functions use local shapes; no image textures or imported assets are sampled to draw particles.

Shader Source in the current plugin uses **ONE / INV_SRC_ALPHA** blending. The shader returns premultiplied RGB, avoiding the bright halos that straight RGB can create. In composite mode, the input is sampled once.

### What is verified

The repository test `python3 tests/verify_wind_drift_events.py` reconstructs the installed OBS Shaderfilter template and its OpenGL `[loop]` preprocessing, checks the source contract and licensing, and compiles the wrapped shader via native `gs_effect_create`. It verifies the expected GPU uniforms on the user's installed Linux libobs / NVIDIA OpenGL stack.

**Not yet established:** a live OBS preview's pixel colors and alpha composition, shader runtime performance at 1080p60/4K60, and behavior when a particular streaming automation toggles scene-item visibility. Native shader compilation is not a visual or frame-time benchmark. Begin with 8–12 particles and monitor OBS rendering lag before increasing count.

## Example directory packaging

The **only** loadable shader file belongs under the installed OBS Shaderfilter `data/examples/myrqyry/` directory. The guide, original MIT license and transparent image stay under `docs/shaders/wind-drift-events/`, so Markdown can't accidentally be picked as a shader.
