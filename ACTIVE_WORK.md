# Active Work — OBS Shaderfilter fork

## 2026-10-22 — Glyph Garden, new opt-in shader

Created `data/examples/myrqyry/glyph-garden.shader` with 30 original
5×5 pictographs in six families, actual pitch-based grid spacing,
optional cell lines and quarter turns, dual-family tone transitions,
four ink schemes, and nine animation modes. It includes its own
necessary blend math with zero file dependencies, deliberately
avoiding the former downloaded-file include regression.

A test-first, real-plugin path verified effect creation and controls,
source passthrough, spacing, a family-invariant empty gutter,
both glyph families, moving rows/columns, checker and breeze modes,
and alpha preservation. A separate detached-file OpenGL probe passed
50 actual readback cases for all nine modes and partial alpha.

The original bitmap25 and Bitmap Glyph Motion remain untouched.
A new glyph-garden.shader data file was copied to the user's
ShaderFilter examples directory and Downloads; its SHA-256 matches
the exact committed repository candidate
(`8cebbf56875ebf976fd451a484a5ab2ceae43135c1e174f73f05bb49a19500be`).
Both real installed-plugin file-loading tests passed. The installed
plugin binary and live OBS scenes were not modified.
See `docs/shaders/glyph-garden/README.md` for controls and limitations.


## 2026-10-21 — Critical Bitmap Glyph deployment fix (real user failure)

**Observation:** The user downloaded `bitmap-glyph-motion.shader` to
`/home/myrqyry/Downloads/` and loaded that exact file in OBS.
The 2026-10-21 live OBS log showed `failed to resolve #include
'/home/myrqyry/Downloads/../../stdlib/colors.glsl'` and
`undefined variable "blendMultiply"`. The original 20/20 native
test falsely passed because it used `wrapper.expand_text` on the file
**while still in the repository**, hiding the broken deployment path.

**Real RED:** `tests/verify-bitmap-glyph-plugin.sh`, built around a
real disposable libobs session and the actually installed
`obs-shaderfilter.so`, reproduced the user's original:
`EFFECT_COMPILED=0 CONTROLS=0 BITMAP_GLYPH_PLUGIN_GPU_PASS=0`.

**GREEN:** The shader now embeds the small reviewed blend helper subset,
and the native test copies the standalone file into a temporary
Downloads-like directory without any adjacent libraries before
compiling the raw contents. All 20/20 GPU tests pass. The actual
ShaderFilter plugin loader then showed
`EFFECT_COMPILED=1 CONTROLS=1 BITMAP_PIXELS_DIFF=98616
MIX_ZERO_DIFF=0 ALPHA_DIFF=0 BITMAP_GLYPH_PLUGIN_GPU_PASS=1`
on that detached file.

**Process correction:** Don't mark user-downloadable ShaderFilter
examples ready based solely on `gs_effect_create` with in-repo
expanded includes. Test the **actual selected file path** through
`obs_source_create("shader_filter")` and `from_file` settings.
Standalone advertised downloads must be genuinely standalone or
shipped with a tested relative-path package.



## 2026-10-21 — Bitmap25 revival: Bitmap Glyph Motion

After reviewing 179 loose, older ShaderFilter artifacts under a local
`obs-shaders` collection, selected the user-authored `bitmap25.shader`
for a scoped revival. **Do not overwrite the original or confuse an
opt-in rebuild with backward-compatible replacement.**

New file: `data/examples/myrqyry/bitmap-glyph-motion.shader`.
Source-backed notes:
[`docs/shaders/bitmap-glyph-motion/README.md`](docs/shaders/bitmap-glyph-motion/README.md).
Exactly 35 original bitmask values preserved (7 sets × 5 tone levels),
checksum-locked in a reproducible test. New cell-level flow/orbit
animation keeps glyph geometry intact. Uses the existing
`data/stdlib/colors.glsl` for true HSL Color/Hue blending rather than
channel swaps. Keeps source alpha and `Mix=0` identity. The streamlined
controls are **intentionally fewer** than the older shader.

**RED/GREEN evidence:** `tests/verify_bitmap_glyph_motion.py`
initially failed for absent shader; after implementation, 20/20
real libobs/OpenGL GPU cases passed (opaque and partial-alpha
variants of ten control transitions). Original `bitmap25.shader`
and user's local `obs-shaders` folder were read-only; no installed
OBS plugin/scenes modified. New `.shader` goes through the actual
ShaderFilter wrapping contract; not an independent `.effect`.

**Remaining acceptance:** interactive UI, large-resolution performance
and Windows/D3D rendering remain unverified. Keep source and test
in the same commit; do not claim visual parity with the original.


## 2026-10-21 — Older authored shader utilities and the real wrapper

The user identified the five uploads as **older self-authored shader files**
and clarified that normal `.shader` source always runs inside the plugin's
built-in effect wrapper unless using a full `.effect` (or manually selecting
Override Entire Effect). Read
[`docs/history/legacy-shaders-20261021/README.md`](docs/history/legacy-shaders-20261021/README.md)
before trying to merge old functions by name.

**Preserved:** four original utility libraries (`blending_modes.shader`,
`lib_color.shader`, `lib_math.shader`, `lib_spatial.shader`) copied
byte-for-byte into a documentation-only history directory, with SHA-256
receipts. The fifth upload `3d-panel.shader` exactly matches the
existing `data/examples/3d-panel.shader`; no duplicate. Historic
blend-mode selection/HSL and UV conventions must not be silently swapped
for present stdlib functions.

**Validated:** `tests/verify_legacy_author_shaders.py` compiles all four
utilities as includes under the actual current ShaderFilter template and
runs an isolated libobs OpenGL readback on the original panel.
All four libraries compile; panel brightness control changed 6,803
pixels in one native comparison. This does not validate an installed OBS
UI session, every control/alpha composition, or numerical equivalence to
modern `data/stdlib/`.

**Scope:** Historical files are not packaged by CMake and no shipped
shaders, stdlib functions, OBS installations or scene settings changed.
The old dispatcher may be a future carefully specified addition, but
porting it is not part of this archive checkpoint.


## 2026-10-21 — Fork Changes claim-by-claim documentation audit

**Scope:** `README.md` feature, bug-fix and build claims, with nearby
usage/build passages checked for contradictory guidance. Source of
truth: `obs-shaderfilter.c`, tracked localized resources, the real
migration manifest and tests. Evidence ledger:
[`docs/FORK_CLAIMS_AUDIT.md`](docs/FORK_CLAIMS_AUDIT.md).

**Provenance follow-up:** Exeldro added the Convert Shader action in March
2024 (upstream `36a8506`), including the converter routines and UI
button. Our fork contributes only defensive checks and UI rearrangement
here; upstream already had the unsafe `convert_define` call disabled.
The README and evidence audit now explicitly credit that origin.

**Corrected overstatements:** groups are not collapsible; the include
guard retains every visited file, possibly rejecting repeated non-circular
includes; function-like macro rewriting is disabled (no general runtime
warning); auto-reload suppresses an unnecessary properties rebuild but
cannot guarantee scroll persistence; compile errors can surface in the
properties error field; raw text auto-reloads after the video-tick
debounce; six additional languages have two untranslated tooltip keys
each. Fixed obsolete paths in the README's example links and the
Meristem project reference to pre-migration test paths.

**Added source-backed omissions:** real missing-file callbacks; file/source
texture pickers and shader annotations; safe 81-path install migration;
OBS 28–33 dynamic image ABI with safe animation-helper fallbacks;
repaired selector defaults/legacy effects; attributed example families;
shader stdlib; Mixwell pixel regression, PSX strict Clang repair,
and actual native GPU suite scopes. The standalone RetroCapture/vGPU
experiments remain explicitly outside OBS integration.

**Validation boundary:** this pass changes Markdown and the explanatory
install-target CMake comment only. Source inspection and pre-existing native
test receipts support the claims, but this documentation update does not
assert a new installed-OBS UI acceptance. No scene data, installed module,
or experimental worktree was touched.


## Current checkpoint — Experimental worktree consolidation (2026-10-21)

**User correction:** Do not merely leave experimental worktrees untouched
and assume somebody else will remember them. Audit every worktree,
understand unique features and verification, incorporate qualified work
into canonical `master`, and preserve enough context for future agents.
The full ten-worktree source/branch/status ledger is
[`docs/WORKTREE_HANDOFF.md`](docs/WORKTREE_HANDOFF.md).

**Integration:** Brought in the historical `aster/installed-union-20261017`
merge preserving its provenance/migration scheme, extra effects, numeric
UI/control repairs, and documented installed OBS verification. Merged
conflicting ACTIVE_WORK chronology without discarding either account.
The three authored shaders inherited from the later `master` were
moved byte-for-byte to `data/examples/myrqyry/local-unpublished/`;
the archive-first migration now enumerates 81 exactly known paths.
No installed plugin or real OBS scenes were modified.

**Real bug recovered:** Standalone Mixwell branch `ba47bf6` included a
real rendering assertion missing from our consolidated source. RED:
render test failed, rotation=0 despite native compile success. GREEN:
changed OpenGL-emitted PI constant to `#define`, native render
passed, rotation=22076; this test now prevents the earlier false
confidence. PSX harness's five macOS strict-Clang aggregate initializer
warnings were also reproduced and corrected; strict compilation
and all four native GPU PSX cases passed.

**Qualification:** Clean out-of-tree CMake/Ninja build, 26 Python
regressions, actual libobs Composite Signal and Soft Register, 4 PSX,
native stdlib, Mixwell render, 5 MPV, 14 PotatoFX, 40 Noisemaker/
printmaking, 24 extra effects, Motion Matte, Wind Drift, 8 repaired
control modes, 5 legacy effect compile cases. Packaged path inventory
and plugin ABI check also passed. This proves these tested paths,
**not** a fresh installed interactive OBS UI or macOS GitHub CI.

**Continuity:** The separate branch commits for Soft Register,
Wind Drift, and Mixwell need not be ancestors to have their qualified
implementation incorporated; see exact distinctions in the handoff
table. No experimental branch ref, original worktree or OBS user
data was deleted. Use this note rather than the old historical
"leave worktrees unchanged" instruction below.


## 2026-10-21 — Master history reconciliation: both shader collections integrated

**Goal:** Resolve the fork's two diverged `master` histories rather than
maintain two competing variants. The user explicitly requested integration.

**History:** pre-merge local tip `3cefa68` (13 local-only commits) and
pre-merge `origin/master` `7dbc211` (26 remote-only commits) have a
normal, conflict-free two-parent merge `93cccf0`. Both parents remain
reachable. Local recovery refs are:
`refs/backup/meristem-obs-local-master-20261021` and
`refs/backup/meristem-obs-origin-master-20261021`. The old local
`31afcfe` backup also remains on GitHub at
`origin/backup/loam-master-20261019`. No force push, reset, rebase or
history rewriting was required.

**Verified on merged source** in an isolated Git worktree, never by
installing over OBS:

- Native out-of-tree **CMake/Ninja RelWithDebInfo build passed** against
  libobs **32.0.1**, producing `obs-shaderfilter.so`.
- **9/9** Python regressions passed.
- Actual libobs composite-signal enabled/disabled pixel comparison passed
  against the freshly built plugin, and all **4** original PSX cases
  compiled and rendered with native graphics.
- Native OBS shader stdlib compile passed including edge expressions and
  the 2 printmaking effects. Mixwell compiled 28 parameters. **5/5 MPV
  anime**, **14/14 PotatoFX palette**, and **40/40 Noisemaker +
  printmaking** real pixel-test cases passed.
- The **staged runtime data** contains both collections: original PSX and
  composite-signal examples plus the newer MPV, Noisemaker, PotatoFX,
  printmaking, Mixwell and `data/stdlib/` resources. The linked plugin
  does not directly import versioned `gs_image_file*` symbols.

These checks establish buildability and independent shader effects running
in libobs in the tested environment. They do **not** establish UI ergonomics
inside a normal OBS session, end-to-end installed-plugin behavior,
subjective appearance of every shader, CI compatibility with OBS 33, or
standalone RetroCapture/vGPU experiments (not rerun). The user-installed
plugin and user's live OBS scenes/settings were not modified. No broad
feature refactor was needed.

**Boundary:** This reconciles the two `master` histories only. Existing
independent experimental feature worktrees remain untouched; they are not
competing canonical `master` versions. A normal fast-forward promotion and
non-force GitHub sync are the next publication actions for this verified
merge. Test details and temporary build paths live in
`.meristem/local/reconciliation-2026-10-21.md` (private and gitignored).
The older divergence entries below remain as historical evidence rather
than as current instructions.


## 2026-10-21 — Documentation reconciliation pass

**Objective:** align developer-facing documentation with the repository's current executable reality, without changing runtime behavior and without touching the diverged integration boundary recorded in the 2026-10-17 entry below.

**Authority used:** current source (`obs-shaderfilter.c`), `data/locale/en-US.ini`, `CMakeLists.txt`, `.github/`, the `data/examples/` tree, and a live out-of-tree build plus GPU test run in this environment.

### Changed

- `README.md` — filter/transition/source display names; supported shader parameter types; two example filenames and one install-tree entry corrected; `install-user` target, libobs version context, and the GPU verification command added.
- `CHANGELOG.md` — the 2026-06-28 entry now states that `tools/`, `templates/`, `data/examples/myrqyry/`, and `data/stdlib/` are gitignored local-only paths that exist in no clone.
- `SESSION-STATE.md` — marked as a historical record; it claimed "Active development" and mixes in another project (`hyperShaderFX`).
- `AGENTS.md` and `.meristem/PROJECT.md` — path precision, plus reconciliation of the resolved changelog/session-state uncertainty and the current divergence.
- `docs/shaders/retrocapture/README.md` and `data/examples/psx/README.md` — in-repo shader path and filter display name.

### Verified

- The command the README documents, `cmake -S . -B build -DBUILD_OUT_OF_TREE=On && cmake --build build`, built `build/obs-shaderfilter.so` against libobs 32.0.1 in a throwaway copy of the tree.
- `tests/verify-composite-signal.sh` ran the freshly built module headlessly and reported `COMPOSITE_SIGNAL_GPU_PASS=1` (enabled pixels differ, zero strength restores the baseline, alpha unchanged).
- Every "Fork Changes" claim in the README was checked against the implementation: 300 ms debounce, `audio_mutex`, the `auto_triggered_reload` guard around `obs_source_update_properties`, disabled `convert_define`, the `convert_db_to_linear` clamp, and the listed `convert_*` bound checks.
- OBS 28.0.0-rc1 headers were checked to contain every libobs API this fork uses, so the CI pin is not stale.

### Preserved intentionally

- The 2026-06-28 changelog entry as a record of a local-only sweep, marked with a scope note rather than rewritten.
- The body of `SESSION-STATE.md` as history; only its status header was corrected.
- The upstream example table as a curated subset; the fork's ported shader families are pointed at, not inlined.

### Still open

- The 2026-10-17 integration boundary is unchanged. Local `master` was 12 commits ahead of `origin/master` `7dbc211` and 26 remote-only commits behind before this documentation commit. No merge, reset, rebase, force-push, or public push was performed, and the installed OBS plugin was not touched.

## 2026-10-17 — Numeric controls and legacy effect compile repairs (source-only)

**Working revision:** integrated local feature branch `aster/installed-union-20261017`, with two separately committed fixes `c6799f1` (parameter defaults/ranges and Noisemaker controls) and `a61438e` (Advanced Displacement native float-to-bool compile errors). The original dirty `~/loam/obs-shaderfilter/master` is unchanged; GitHub was **not pushed**. The **installed user-local plugin and shader library were not updated during this pass**; the installed on-disk binary remains the previously verified SHA `9e68b88d79dc35618ec7722f0dfde97dbe14c7c075d3c010cda1ee2d4b7799b2`. Existing OBS scenes and other apps were not touched.

- Audited **285 installed shader/effect files**, **2,228** uniform declarations, cross-checked shader property generation in `obs-shaderfilter.c` and corrected scalar/vector scanner false positives. Full review in the private `.meristem/local/parameter-audit-2026-10-17.md` under the original checkout.
- **Source fixes:** widen three legal numeric ranges to admit **unchanged** defaults (emboss color amp=12, fire tongue=8.5, denoise sigma=5); advanced displacement dropdowns default to the existing selectable Linear value `1` rather than invalid `0`. Both 0 and 1 used the same pre-existing linear iteration behavior.
- **Noisemaker controls:** `nm_edge` kernel now reaches mode `2` (Contour); size, blend and three threshold-controlled binary inputs use meaningful integral steps/bounds. `nm_sine` RGB/grayscale switch uses 0/1 and `nm_glowingEdge` Sobel metric uses four discrete values. The shader uniforms remain **float**, not switched to int/bool, to minimize saved-profile type churn; these are stepped numeric sliders, **not named dropdowns/checkboxes**. Meaningful labels and persisted out-of-range legacy scene values should be checked separately before any UI migration.
- **Unexpected real native compile defect:** Advanced Displacement normal and inverted versions used float `chromatic_aberration` as an implicit bool twice; actual libobs/NVIDIA shader compiler rejected both with C7011. Two `!= 0.0` checks per shader removed the compile errors without changing the arithmetic or defaults.
- **Tests:** RED first (**13** source-contract subcase failures), then GREEN. **26/26** full Python unit regressions, a clean CMake/native module build, **40/40** complete Noisemaker GPU effects, **8/8** real control-mode pixel differences (all alpha preserved), **5/5** formerly affected legacy shaders compiled in actual NVIDIA libobs. Distinct tests: `tests/test_shader_control_ranges.py`, `tests/verify_shader_control_modes.py`, `tests/verify_repaired_shader_compilation.py`. No claim that all artistic defaults or arbitrary profile-migration paths have been visually qualified.
- **Open P2:** 18 off-step author defaults (15 fork-authored) and broad percentage slider granularity remain documented but **not changed** without visual comparison and user UX priorities. Numeric controls updated in source should be installed only with a fresh backup/manifest parity check and a conscious OBS activation decision. Keep the prior full installation/scene backup.

## 2026-10-17 — Consolidated local install (after divergence audit)

- **Installed on disk:** latest GitHub `master` (`7dbc211`), nine local shader-feature commits and the already-stacked provenance/extra-shader branches were merged in an isolated `aster/installed-union-20261017` worktree. The resulting native Shaderfilter 2.6.0 module was built and installed into the existing **user-local OBS plugin directory**. No GitHub publication, repository `master` merge, OBS process restart, system-plugin install, or other project mutation.
- **Consolidated source tests:** 23 Python unit/provenance/migration tests; CMake native module compilation; seven native stdlib headers; 40 Noisemaker/printmaking pixel cases, five MPV, 14 PotatoFX, 24 additional effect cases, motion matte and wind drift; native PSX x4 and Composite Signal with true zero-strength bypass; soft-register check. These ran before the on-disk swap. The actual newly installed plugin binary then passed a fresh isolated libobs/OpenGL Composite Signal check with unchanged alpha and correct strength-zero bypass.
- **Shader reconciliation:** the branch's CMake migration manifest covers 78 *known* old paths. On this actual user installation 15 were present and archived under the installed data's `legacy-shaderfilter-examples-backup/`. A 276-file complete previous installation and OBS scene snapshot were also preserved in a private local backup, with 365 files in the final active on-disk installation. All 286 merged-source data files match their installed copies; any old changed standard-library files remain recoverable in the full backup. The three separate unpublished local shaders were copied byte-for-byte to `data/examples/myrqyry/local-unpublished/`; their Loam originals remain untouched.
- **Scene compatibility:** all four previously resolving scene references inside this plugin directory still resolve after the installation. Three old `data/examples/mqy/` references were already missing; no genuine original files could be found in nearby worktrees/history. Their associated scene-embedded shader text is saved privately as **candidates only**, not installed under misleading original filenames (two paths contained identical unrelated PSX text).
- **OBS activated after user-side restart:** a new OBS process loaded the **exact user-local installed module**. The `/proc/2643257/maps` entry points to the plugin directory; SHA-256 of the mapped library and installed file both equal `9e68b88d79dc35618ec7722f0dfde97dbe14c7c075d3c010cda1ee2d4b7799b2`. The OBS startup log on October 17 at 21:22 reports `[obs-shaderfilter] loaded version 2.6.0` and created Shaderfilter filter instances in real scenes. **The assistant did not restart or stop OBS.** This proves correct real OBS module loading, not every effect, scene or interactive configuration.
- **Rollback and evidence:** backup path, file reconciliation JSON, source SHA and private scene texts are in the private local verification receipt `obs-shaderfilter/.meristem/local/verification-2026-10-17.md`. The full previous plugin tree remains in the local Meristem backups area. Preserve the clean integration branch and the user's dirty original `master` separately; do not push or merge into public `master` without an explicit publication decision.

## 2026-10-17 — Diverged-history verification checkpoint

**Checkout:** `~/loam/obs-shaderfilter` (public fork `myrqyry/obs-shaderfilter`). Local `master` at `fd94714` before this documentation checkpoint; after a non-destructive fetch, `origin/master` is `7dbc211`. The ancestry is **nine local-only commits ahead / 26 remote-only commits behind**. These are independent changes; do **not** force-push, reset, rebase, or merge automatically.

**Unfinished working state deliberately preserved:** modified `.gitignore`; untracked `AGENTS.md`, `.meristem/`, and three shader examples `data/examples/canny_edge.shader`, `pixel_sort.shader`, `text_3d_sdf.shader`. Other OBS shader worktrees exist and were not altered. All pre-existing paths and contents remain exactly where they were.

### Fresh verified checks

- Created **two immutable source archives** under `/tmp` from committed `fd94714` and `origin/master` `7dbc211` respectively; both configured and built separate native `obs-shaderfilter.so` modules against libobs 32.0.1 using CMake/Ninja, with **no install to OBS** or builds in the dirty checkout. Neither build establishes installed-plugin operation.
- **Local committed snapshot:** isolated actual libobs/OpenGL `tests/verify-composite-signal.sh` passed with the newly built module (enabled shader pixels differ from baseline, zero-strength restores baseline exactly, alpha unchanged). Four PSX shaders passed native GPU compile/render tests with visible output and time-dependent effects as appropriate; log identified NVIDIA RTX 2070 SUPER. No untracked local examples were included in these runs.
- **Current remote committed snapshot:** 9 Python regression tests passed; native OBS stdlib compilation passed all seven headers plus combined/edge/printmaking checks; Noisemaker/printmaking **40/40 real GPU pixel cases** passed; MPV anime **5/5** passed; PotatoFX palette **14/14** cases passed; Mixwell native effect compile passed (28 parameters).
- Tested checks protect shader compilation and specified pixels in isolated environments, not subjective effect aesthetics, production OBS installation or 100% coverage of all local nine commits. WebGPU dual-adapter and standalone RetroCapture pipelines were **not rerun** here. Neither side's code was merged with the other.

### Integration and publication boundary

Git's refreshed remote history contains additional shader families, numerical fixes, native stdlib headers and CI modernization; the local nine commits contain other shader examples and tests. Their changed-file sets do not directly overlap at file-path level, **but absence of name conflicts does not establish semantic compatibility**. Preserve both histories, and later construct an isolated integration candidate with both native shader/GPU suites before touching shared `master`.

**No public branch push of the nine local commits in this pass.** The current working tree has unfinished user files and divergence; this documentation commit is a local history checkpoint, not a merge/release. User's installed OBS Shaderfilter module and running Droplette were untouched. Private machine receipt: `.meristem/local/verification-2026-10-17.md`.
