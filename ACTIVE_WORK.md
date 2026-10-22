# Active Work — OBS Shaderfilter fork


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
