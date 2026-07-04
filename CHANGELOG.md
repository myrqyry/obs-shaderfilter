# Changelog

## 2026-06-28 — Library modernization pass

This changelog covers a one-time sweep that added metadata headers, cross-platform fixes, and tooling across the entire example library. Going forward, entries will track individual shader additions and fixes.

### Added
- **`tools/lint.py`** — Cross-platform + metadata linter. Detects missing UV flips, C-style casts, 1-arg float3 broadcasts, missing header metadata, `previous_output` references without declaration, and more. Run with `python3 tools/lint.py`.
- **`tools/autofix.py`** — Safe mechanical fixes for the lint issues. Run with `python3 tools/autofix.py` to repair `.f` suffixes, add OPENGL UV flips, fix C-casts and broadcast constructors in bulk.
- **`tools/add_headers.py`** — Add `@name`/`@category`/`@complexity`/`@tags`/`@description` metadata headers to any shader that lacks them. Infers category from filename and content; falls back to a generated description.
- **`tools/add_notes_widget.py`** — Add an OBS `Notes_Header` info widget to every shader, populated from the header metadata, so users see what each shader does in the OBS properties panel.
- **`data/examples/_template.shader`** — Heavily-annotated starting point for new contributors. Fork this file, fill in the TODOs, and you have a cross-platform-ready shader.
- **`data/examples/CATALOG.md` + `CATALOG.json`** — Auto-generated catalog of all 211 shaders, categorized and tagged. Regenerate with `python3 tools/lint.py --catalog`.
- **`data/examples/INDEX.md`** — Flat one-line index for quick scanning.
- **`data/examples/COMBINATIONS.md`** — 11 tested filter-chain "looks" with parameter starting points (Cinematic Noir, VHS Horror, Retro Arcade, Webcam Beauty, etc.).
- **`templates/`** — 5 starter templates: `audio-reactive.shader.tmpl`, `temporal-feedback.shader.tmpl`, `uv-displace.shader.tmpl`, `color-grade.shader.tmpl`, `glitch.shader.tmpl`. Plus `templates/README.md` explaining usage.
- **`data/examples/myrqyry/README.md`** — Documents the personal-experiments subfolder.
- **6 new shaders** in `data/examples/`:
  - `kaleidoscope.shader` — N-segment kaleidoscope with rotation animation
  - `halftone_color.shader` — CMYK print-style halftone with per-channel angles
  - `lens_correction.shader` — Barrel/pincushion lens correction
  - `crosshatch.shader` — Pen-and-ink crosshatch illustration
  - `depth_of_field.shader` — Approximate DoF via brightness-driven bokeh
  - `pixel_sort.shader` — Glitch-art pixel sort
- **3 stdlib composition showcases**:
  - `stdlib_fireplace.shader` — Domain-warped FBM fireplace
  - `stdlib_ocean.shader` — Domain-warped FBM ocean
  - `stdlib_plasma.shader` — Sin + FBM plasma

### Changed
- **Cross-platform fixes applied to ~190 shaders**: 185 OPENGL UV flips, 27 invalid `.f` literal suffixes, 2 C-style casts. All shaders now render correctly on Linux/macOS (OpenGL backend).
- **Headers added to 201 shaders** that previously had no metadata.
- **`Notes_Header` info widget added to 195 shaders** so users see the description in OBS properties without opening the source.

### Notes
- The `myrqyry/` subfolder remains as the maintainer's personal-experiments area. See `data/examples/myrqyry/README.md` for the rationale.
- Header metadata is auto-generated; descriptions are best-effort from existing comments. Future improvements: hand-curate descriptions for the most-used shaders.
- No existing shader was renamed, removed, or had its public behavior changed. Cross-platform fixes are purely additive (added `#ifdef OPENGL` blocks, replaced `0.5f` with `0.5`, etc.).
