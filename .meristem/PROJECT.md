<!-- meristem-template:v1 -->
# Project

## Purpose

An OBS Studio plugin that lets users author and load OBS-compatible HLSL shaders as filters, transitions, and a standalone generative source. The repository also maintains a large example-shader library.

## Invariants

- Shader/effect files are user-authored GPU programs interpreted by OBS's effect system; this is not an arbitrary GLSL runtime.
- Keep the plugin's filter, transition, and shader-source behaviors compatible with OBS/libobs and the documented shader parameter conventions.
- The standalone source and filter/transition are separate OBS source modes in the implementation; avoid assuming filter-only input or padding behavior applies to every mode.

## Architecture and boundaries

`obs-shaderfilter.c` owns native OBS source/filter registration, properties, shader loading/conversion, parameter binding, and rendering. `data/examples/` contains sample shaders/effects; `data/internal/` contains the bundled internal effect; `data/locale/` and `data/textures/` provide runtime resources. CMake owns out-of-tree build/install rules and requires libobs. The README is the user-facing authority for usage and shader conventions; `CHANGELOG.md` records project changes. No separate ADR system was found.

## Known-good workflows

Build using the CMake workflow described in `README.md` and the platform automation under `.github/`. The maintained CMake target is `obs-shaderfilter`; on POSIX out-of-tree builds, `install-user` copies the plugin and data into the user's OBS plugin directory. No repository-wide test target or locally available shader lint command was established during initialization.

## Verification

Use the configured CMake build against the intended libobs/OBS version to verify native changes. Shader behavior ultimately requires loading the effect in OBS; compilation alone does not verify visual output. CI build workflows live in `.github/workflows/build.yml`.

## Open structural uncertainty

`CHANGELOG.md` describes a 2026-06-28 library modernization and refers to `tools/lint.py`, `tools/autofix.py`, shader catalog files, and templates; those paths were not present in the current root listing, and `python3 tools/lint.py --help` fails because the file is absent. Reconcile the changelog against the current tree before relying on those workflows. `SESSION-STATE.md` contains an old, mixed-project chronology and claims active development, but the current checkout is clean and aligned with `origin/master`; it is preserved as historical context, not adopted as the current-work authority. No `ACTIVE_WORK.md` is warranted from current Git state.
