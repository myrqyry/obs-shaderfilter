# ShaderFilter experimental worktree handoff — 2026-10-21

The experimental worktrees were inventoried after the 2026-10-21
`master` reconciliation. **They were not disposable copies.** Many were
the sole locations of tested features, an installed-plugin integration
receipt, and the proofs needed to finish publishing them. This is the
portable handoff for future agents: read it before assuming that every
feature branch is obsolete or that a passing merge proves runtime behavior.

## Canonical outcome

`master` is intended to be the single maintained shader source. The
`aster/installed-union-20261017` branch contributes the organized
`data/examples/myrqyry/` library, provenance and safe install migration,
the tested extra shader families, numerical control repairs, native shader
compile repairs, and archived real-OBS installation knowledge. Its
history is incorporated by a **normal Git merge**, not a squash or
replacement. Its Oct 17 verification is preserved historically in
`ACTIVE_WORK.md`, including what was *actually* loaded in OBS at the
time. That older installed plugin is not proof that the new merged build
is installed: it has **not been reinstalled** during this consolidation.

Three later master-authored shaders `canny_edge.shader`,
`pixel_sort.shader`, `text_3d_sdf.shader` were carried byte-for-byte
into `data/examples/myrqyry/local-unpublished/`. The bounded installer
manifest now covers **81** exactly known relocated paths, with
preflight and archive-before-move semantics. The former root PixelSort
on the user's **installed** plugin has different bytes from the
tracked source file; it was deliberately **not overwritten**. Future
`install-user` would archive that old file first, provided no archive
collision occurs. OBS scene JSON did not reference these three names
during the 2026-10-21 read-only check. Installation is a separate step.

## Worktree/branch inventory and disposition

| Worktree (under Loam's .worktrees) | Branch tip | Integration status |
|---|---|---|
| `obs-mpv-ports` | `7daf70c` | Commit is already an ancestor of `master`; five real native GPU tests pass |
| `obs-noisemaker` | `dc0956c` | Already an ancestor; 40 real Noisemaker/printmaking GPU cases pass |
| `obs-potatofx` | `f8352a7` | Already an ancestor; 14 native palette cases pass |
| `obs-stdlib` | `ba69dc3` | Already an ancestor; native libobs stdlib compilation passes |
| `obs-examples-sort` | `f57a8f4` | Incorporated through installed-union ancestry; source-provenance and migration tests pass |
| `obs-more-effects` | `ce3dfbf` | Incorporated through installed-union ancestry; 24 additional native GPU cases and motion matte pass |
| `obs-shaderfilter-installed-union-20261017` | `da04213` | Integrated as a merge parent; source control-range/legacy compile fixes and previously verified installed OBS module history preserved |
| `obs-mixwell` | `ba47bf6` | Functionality **ported**, not that commit's exact Git ancestry: fixed `FLUID_GLASS_PI` to preprocessor constant; strengthened test checks genuine GPU output. RED showed rotation=0, GREEN showed rotation=22076 |
| `obs-soft-register` | `05a7c1a` | Updated relocated implementation already in installed-union; its actual native `verify-soft-register` script passes; commit ancestry distinct |
| `obs-wind-events` | `219020a` | Updated relocated implementation already in installed-union; native compile and additional pixel/alpha tests pass; commit ancestry distinct |

A separate local branch `aster/wind-drift-events` exists without
its own attached worktree; it was not removed or reset. All ten listed
worktrees were **clean** when inventoried. Older branch refs remain
recoverable locally and, where already published, on GitHub. Do not
delete branch refs or worktree directories by inference: retire them
only after verifying both ancestry/semantic coverage **and** absence of
active workflows or unique local assets.

## Actual evidence on the consolidated source

- Out-of-tree CMake/Ninja plugin build against **libobs 32.0.1** passed;
  26/26 Python unit tests passed, including migration/provenance checks.
- Real libobs GPU checks passed: Composite Signal, Soft Register, four
  PSX cases, stdlib/printmaking compilation, five MPV, 14 PotatoFX,
  40 Noisemaker/printmaking, **24 additional effect cases**, Motion
  Matte, Wind Drift, eight repaired selector modes, and five repaired
  legacy shader compiles.
- **Mixwell recovered bug:** the older test checked only compile. The
  ported stricter native GPU check failed (rotation=0) with
  `static const FLUID_GLASS_PI`; after the proven branch fix it passed
  (rotation=22076). This is verified pixel behavior, not just syntax.
- Reproduced the macOS CI PSX example harness's five
  `-Werror,-Wmissing-braces` diagnostics using local Clang 18;
  correcting struct initialization passed the strict Clang check
  and rerunning all four actual PSX native GPU render cases.
- Packaged resources checked for all migrated categories, including
  all three original local shaders. No direct versioned
  `gs_image_file*` ABI dependency was found.

The tests do **not** verify a freshly installed plugin in interactive
OBS, specific saved-scene transitions, macOS CI outcome for this
new commit before it runs, or separate standalone RetroCapture/vGPU
experiments. Private full logs/receipts reside with the project's
Meristem local state; do not publish private OBS scene data or the
installed user-plugin tree. Preserve full historic reasoning in
`ACTIVE_WORK.md` and associated feature branch commits, rather than
rewriting the old accounts to appear current.

## Next real use

Once published, inspect GitHub CI (macOS in particular), then choose a
separate deliberate OBS install/scene acceptance with backup and
reversible migration. The end state should be **one maintained fork**,
not agents independently implementing features again because the
experimental worktree context was forgotten.
