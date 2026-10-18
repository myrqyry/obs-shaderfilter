# Active Work — OBS Shaderfilter fork

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
