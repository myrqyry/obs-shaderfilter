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

Build using the CMake workflow described in `README.md` and the platform automation under `.github/`. The maintained CMake target is `obs-shaderfilter`; on POSIX out-of-tree builds, `install-user` copies the plugin and data into the user's OBS plugin directory. Standalone builds are verified with `cmake -S . -B build -DBUILD_OUT_OF_TREE=On && cmake --build build` (confirmed against libobs 32.0.1 on 2026-10-21). There is no repository-wide CMake test target and no shader lint command; the closest executable checks are `tests/verify-composite-signal.sh` (headless libobs render of `data/examples/composite_signal.shader`) and `data/examples/psx/verify_psx.sh`.

## Verification

Use the configured CMake build against the intended libobs/OBS version to verify native changes. Shader behavior ultimately requires loading the effect in OBS; compilation alone does not verify visual output. CI build workflows live in `.github/workflows/build.yml` and build against OBS 28.0.0-rc1.

## Open structural uncertainty

Resolved on 2026-10-21. `CHANGELOG.md` describes a 2026-06-28 library modernization and refers to `tools/lint.py`, `tools/autofix.py`, shader catalog files, and templates; those paths are deliberately gitignored local-only directories (`.gitignore` lists `tools/`, `templates/`, `data/examples/myrqyry/`, `data/stdlib/`) that never appeared in any commit, so they cannot exist in a fresh clone. `CHANGELOG.md` now carries an explicit scope note saying so; the changelog records that local sweep, not tracked repository content.

`SESSION-STATE.md` contains an old, mixed-project chronology and previously claimed active development; it now carries a status banner marking it a historical record superseded by `ACTIVE_WORK.md` and this file.

The two former `master` histories were reconciled on 2026-10-21 by the conflict-free two-parent merge `93cccf0`, with both parents and separate recovery refs preserved. The merged tree built successfully against libobs 32.0.1 and passed real GPU/native shader regression gates across both example collections. The relevant checkpoint and remaining normal OBS UI/installation uncertainty are in `ACTIVE_WORK.md`. Prior divergence entries are historical, not a requirement to keep two `master` versions. The subsequent experimental worktree integration and complete branch ledger
are recorded in `docs/WORKTREE_HANDOFF.md` and at the top of
`ACTIVE_WORK.md`. The Oct 17 installed-union feature work, relocated
myrqyry example library and follow-up Mixwell GPU fix were incorporated
into the integrated source on Oct 21. A tested source merge must not be
mistaken for a newly installed OBS module or for deleting branches.
