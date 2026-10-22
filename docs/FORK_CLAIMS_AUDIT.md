# ShaderFilter fork claims audit — 2026-10-21

Scope: `README.md`'s **Fork Changes** claims, plus contradictory usage
instructions and relocated library references. Evidence priority is
the committed `obs-shaderfilter.c` and `CMakeLists.txt`, tracked assets,
tests and machine-run native GPU receipts. This is an **implementation
audit**, not an independent interactive OBS UI verification of every claim.

| Claim | Evidence | Finding and limitation |
|---|---|---|
| Generative source | `obs-shaderfilter.c`: `shader_source` registration, `shader_source_render`, width/height defaults and controls | Implemented. Procedural shader can render without target; shaders sampling `image` do not magically acquire an input. |
| Debounced inline editor | `shader_filter_text_changed`, `shader_filter_tick` | 300,000,000 ns deadline; timer evaluated on video ticks. Old usage text incorrectly required manual reload for each text edit. |
| Raw/file toggle | `shader_filter_init_source_mode`, `shader_filter_raw_shader_changed` | File is default for new instances without saved raw text. Old settings respected. |
| OBS source-picker texture | `GS_SHADER_PARAM_TEXTURE` properties and `obs_enum_sources`/`obs_enum_scenes` | Implemented property lists; not separately retested in GUI. |
| UI groups | `shader_filter_properties` and `OBS_GROUP_NORMAL` | Organized but not collapsible. Padding group is filter-only; annotations can introduce more groups. |
| Range/widget metadata | `GS_SHADER_PARAM_INT/FLOAT/VEC*` property creation and `tests/test_shader_control_ranges.py` | Source-backed; several repaired defaults/modes tested. Arbitrary shader correctness not guaranteed. |
| Tooltip/padding | `ShaderFilter.ExpandPixels.Tooltip`, four edge `obs_properties_add_int` calls | True. Pixel padding affects filter path, not independent generator. |
| Locales | `data/locale/*.ini` key inventory | Six locale additions each supply 28 of 30 `en-US` keys, missing `ShaderFilter.ExpandPixels.Tooltip` and `ShaderFilter.OverrideEntireEffect.Tooltip`. |
| Linux install | `CMakeLists.txt` `install-user`, `cmake/MigrateLegacyExamples.cmake` and 81-entry manifest | Target and bounded archive-first migration implemented. Backups are never overwritten; unrelated files remain. |
| Circular includes | `load_shader_from_file_internal` global `visited` list | Terminates repeated recursion but may also skip a legal second include. Do not claim stack-accurate cycle detection. |
| Include error reporting | `load_shader_from_file_internal` | Emits malformed-quote, unreadable-file and unresolved-include messages; the former claim of “invented path warnings” was imprecise. |
| Shader-file ownership | `load_shader_from_file_internal` nulls `shader_file.array` before `dstr_free` | Prevents immediate freeing of the returned buffer. No heap-sanitizer reproduction was conducted in this audit. |
| Audio thread safety | `shader_filter_audio_callback` and `shader_filter_tick` mutex locks | Protects shared meter values across these paths, not a claim of exhaustive threading proof. |
| String cleanup | `shader_filter_clear_params` and `shader_filter_update` | Releases prior string value and default allocations. |
| Converter boundary guards | `convert_atan`, `convert_mat_mul_var`, `convert_mat_mul`, `convert_return` and `shader_filter_convert` | Defensive checks exist; not a proof of general parser correctness or full GLSL support. |
| `convert_define` macro stripping | `shader_filter_convert` | The rewrite is commented out; no general runtime warning or safe function-macro rewrite established. |
| Auto-refresh scroll | `shader_filter_update` `auto_triggered_reload` conditional | Suppresses one unnecessary property-update call; UI can still refresh in other circumstances. |
| Color defaults | `GS_SHADER_PARAM_VEC3`/`VEC4` handling | White 0xffffffff when non-slider color control has no annotation default. |
| Audio range | `convert_db_to_linear` | Explicit <= -60 dB → 0; >0 dB → 1; clamped interpolation otherwise. |
| `da_push_back` / `nullptr` | Group array uses `da_push_back(groups, &p)` and no bundled `nullptr` definition in current source | Source-backed build-compatibility claim; native out-of-tree and CI builds exercise compilation. |
| OBS 28–33 image helpers | `obs_module_load` dynamic `os_dlsym` branches and `shader_filter_tick` paired function checks | Version-aware symbol resolution and missing-helper behavior exist; not exhaustive runtime testing across every OBS version. |
| Compile/error messaging | `shader_filter_reload_effect` sets `last_error`; `shader_filter_properties` creates an error info property | Errors can be shown when OBS builds the properties view, as well as logged; old README wrongly implied no errors were available. |
| Missing-file handling | `shader_filter_missing_files` | Source registers OBS missing-file callback for external shader and image files. |
| Reorganized shader collection | `data/examples/myrqyry/README.md` and `tests/test_example_provenance.py` | Attributed paths checked into Git and tracked in installer. Source names do not imply identical third-party runtime semantics. |
| Preserved local shaders | `tests/test_example_migration.py`, 81-item `cmake/legacy-example-paths.txt`, `docs/WORKTREE_HANDOFF.md` | Three originals relocated byte-for-byte; migration archives known old installed paths rather than overwriting. |
| Native shader helpers | `data/stdlib` and `tests/verify_stdlib.py` | Seven native compile cases/headers plus printmaking checks; not every possible formula/input validated. |
| Effect render regressions | `tests/verify_*.py`, PSX and composite/soft-register scripts, `ACTIVE_WORK.md` | Real NVIDIA/libobs tests: 40 Noisemaker/printmaking, 5 MPV, 14 palette, 24 additional, PSX, Mixwell, motion, wind, selector and repaired legacy cases; scope-limited. |
| Recovered Mixwell bug | `data/examples/myrqyry/mixwell-fluid-glass.shader`, `tests/verify_mixwell_fluid_glass.py` | RED (rotation=0), GREEN (rotation=22076) on genuine libobs OpenGL readback; compilation alone missed it. |
| macOS PSX warning | `data/examples/myrqyry/psx/verify_psx.cpp`, GitHub CI and documented local Clang reproduction | Five missing-braces warnings fixed. Strict local Clang gate and native four-case test passed; CI still the authoritative cross-platform gate. |
| CI and platform claims | `.github/workflows/build.yml` and `compatibility.yml`, GitHub Actions | Reports should distinguish build/ABI checks from actual effect output and installed OBS UI checks. |
| RetroCapture and vGPU experiments | `experiments/retrocapture-graph/` and `experiments/vgpu-graph/` | Standalone labs, explicitly not OBS plugin integration. |

**Not independently established by this audit:** interactive behavior of every
control in running OBS, 1080p60 or 4K frame cost, complete shader-language
correctness, full translation coverage, and platform parity for every
individual effect. The previously observed October 17 installed-plugin test
applies to that exact binary, **not** every subsequent source commit.

Avoid broad “UI overhaul”, “completely compatible”, “all shaders verified”,
or “no errors” claims without direct acceptance evidence.
