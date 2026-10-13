# ORPHIC → OBS ports (2026-10-13)

Source: [ORPHIC](https://github.com/adityarajashekaran/orphic), commit `47a8d5d`, © 2026 Aditya Rajashekaran. Derived files carry `SPDX-License-Identifier: AGPL-3.0-or-later` and attribution; treat redistribution of this mixed-license collection as a separate licensing review, not as automatically covered by ShaderFilter's repository license.

These standalone `.shader` files target the **standard ShaderFilter wrapper**, file-backed mode, with user controls and OBS `audio_peak` / `audio_magnitude` uniforms:

| File | Transfer | Differences from ORPHIC |
|---|---|---|
| `orphic_chladni.shader` | Three standing-wave eigenmodes, shimmering domain warp, glowing nodes | Manually selected mode families; peak/RMS instead of FFT-band weights and beat-triggered mode retuning |
| `orphic_hyperdrive.shader` | Polar demoscene tunnel, spokes, derivative fade, star streaks, chromatic depth | Periodic rather than event-queued beat rings; stable clock rather than accumulated music-driven travel |
| `orphic_escher_gate.shader` | Poincaré disk tiling through triangle-group folds | Manual {p,q} selection; peak/RMS rather than spectral texture and 16-beat retiling |

**How to use:** Add a **Shaderfilter Source** or attach a **Shaderfilter Filter** to an existing OBS source. Select the `.shader` file, **leave Full Vertex Shader (.effect) off**, use **Reload Effect**, and choose an audio source in the filter settings if needed. `Mix With Source = 1` uses the generated scene; `0` leaves the input source unchanged. For full-screen visuals, the standalone source is preferable.

**Verified:** All three compiled with native libobs 32.0.1 OpenGL effect compilation, using the *actual standard wrapper text from this checkout*, and rendered nonempty frames through Mesa llvmpipe at 256×144. Installed copies under `~/.config/obs-studio/plugins/obs-shaderfilter/data/examples/` were byte-identical when copied. No real microphone/audio-device routing, shader UI interaction, Windows/macOS backend, full-resolution performance, or visual parity test was completed. An isolated direct **Shaderfilter Source** module harness returned an empty frame and the default 1920×1080 dimensions; this may be missing OBS scheduler/tick setup in the harness, but **that path has not passed runtime verification**. Do not conflate the two boundaries.

**Stateful follow-up:** `~/MQR/hyperShaderFX/data/shaders/root/orphic_turing_bloom.effect` demonstrates genuine Gray-Scott feedback with a reversible chemical-state encoding in RGB. This is not a full port of ORPHIC's multi-target simulation. Direct libobs GL verification observed different image checksums at frames 1, 24 and 90 at 160×96; runtime integration and long-term stability remain separate tests. HyperShaderFX already has a distinct native `chladni_resonance.effect`, so do not duplicate it.

For the original Physarum, fluids, Lenia, star river, or swarm scenes, a full port needs independent simulation render targets, separate update and display passes, and for particles a deposition/draw path. HyperShaderFX's `iPreviousFrame` alone is not that pipeline.

## Additional ports (2026-10-13)

- `orphic_obsidian_sanctum.shader` — an additional ShaderFilter one-pass Mandelbox raymarcher based on ORPHIC `js/scene-obsidian-sanctum.js`. Controls bound the default raymarch to 40 steps and 8 fractal iterations rather than ORPHIC's 96 x 11 full raymarch plus adaptive-resolution upscaling. Traces original box/sphere folds, orbit-trap material and normal/fresnel lighting; replaces spectral glow with audio peak/RMS and omits separate AA/chromatic postpass. **Native libobs 32.0.1 OpenGL (llvmpipe) compiled and rendered a nonempty 256×144 frame, checksum 15082048**. Significant frame cost at full OBS resolution is not evaluated. Do not claim full-res performance.
- `~/MQR/hyperShaderFX/data/shaders/root/orphic_aurora_veil.effect` — an additional HyperShaderFX native audio-reactive aurora shader based on ORPHIC `js/scene-aurora-veil.js`. Keeps procedural starfield, two domain-warped curtain layers, palette, horizon and flow. Uses **eight independent HyperShaderFX FFT band uniforms** interpolated across the sky, rather than ORPHIC's peak-decay FFT spectrogram history; live audio capture still needs an OBS integration check. Native libobs 32.0.1 OpenGL render test at 256×144 **passed** with opaque and colored output. Synthetic audio profiles gave distinct pixel checksums: silence `9653386`, bass `11699619`, treble `11895829`. This establishes shader responsiveness to externally supplied uniform values, **not** the entire real audio-device pipeline.

The additional source and installed OBS library copies are byte-compared at install. No system OBS binaries or plugin code are altered.
