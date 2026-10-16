# Shaderfilter examples: upstream and fork

This directory deliberately retains the **164 original files** from
[exeldro/obs-shaderfilter](https://github.com/exeldro/obs-shaderfilter)
at their canonical upstream paths (the `.shader` and `.effect` files directly
inside `data/examples/`). The original files are byte-identical to our
upstream `master` snapshot used for this split. Keeping their paths unchanged
preserves existing upstream-based OBS presets and makes future upstream
synchronization straightforward.

**Our fork's additions are under [`fork/`](fork/README.md)**. This includes
our own shaders, third-party adaptations, and their licenses/documentation;
they are not represented as work by the upstream OBS Shaderfilter author.

The built-in OBS file picker opens this `examples` directory. Enter `fork/`
to browse the additions. Both directories are packaged by the existing CMake
`data/examples` installation rule.

**Migration:** Previously selected fork-added shaders at e.g.
`.../examples/noisemaker-ports/nm_polar.shader` must be reselected at
`.../examples/fork/noisemaker-ports/nm_polar.shader`. The picker uses file
paths; it does not automatically remap old presets. Canonical upstream
examples retain the same paths. Existing fork-added paths are not kept as
redundant copies or aliases, so the two collections stay separate.

Provenance is checked against `tests/fixtures/upstream-example-paths.txt`
(snapshot of the upstream example tree). Update that snapshot when intentionally
syncing new upstream examples; put any new fork-authored or adapted shader
under `fork/`.
