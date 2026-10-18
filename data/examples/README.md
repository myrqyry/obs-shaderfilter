# Shaderfilter examples: upstream and myrqyry

This directory deliberately retains the **164 original files** from
[exeldro/obs-shaderfilter](https://github.com/exeldro/obs-shaderfilter)
at their canonical upstream paths (the `.shader` and `.effect` files directly
inside `data/examples/`). The original files are byte-identical to our
upstream `master` snapshot used for this split. Keeping their paths unchanged
preserves existing upstream-based OBS presets and makes future upstream
synchronization straightforward.

**Our myrqyry additions are under [`myrqyry/`](myrqyry/README.md)**. This includes
our own shaders, third-party adaptations, and their licenses/documentation;
they are not represented as work by the upstream OBS Shaderfilter author.

The built-in OBS file picker opens this `examples` directory. Enter `myrqyry/`
to browse the additions. Both directories are packaged by the existing CMake
`data/examples` installation rule.

**Migration:** Previously selected fork-added shaders at e.g.
`.../examples/noisemaker-ports/nm_polar.shader` must be reselected at
`.../examples/myrqyry/noisemaker-ports/nm_polar.shader`. The picker uses file
paths; it does not automatically remap old presets. Canonical upstream
examples retain the same paths. Existing fork-added paths are not kept as
redundant copies or aliases, so the two collections stay separate.

Provenance is checked against `tests/fixtures/upstream-example-paths.txt`
(snapshot of the upstream example tree). Update that snapshot when intentionally
syncing new upstream examples; put any new fork-authored or adapted shader
under `myrqyry/`.

### Updating an existing Linux user installation

The CMake **`install-user`** target archives **only the 78 known former
example paths** from earlier myrqyry ports and local fork additions into
`~/.config/obs-studio/plugins/obs-shaderfilter/data/legacy-shaderfilter-examples-backup/`
*before* installing the new `data/examples/myrqyry/` layout. The original bytes,
including any edits to those old example files, are preserved in the archive.
Unrelated custom shader files and sibling directories are left in place.
If an archive destination already exists for a path that needs migrating,
the target stops rather than overwriting either file. Repeated installations
without old files to migrate do nothing. Other installers or copying files
manually do **not** run this migration script.

Because the old saved file paths are no longer active, existing OBS presets
referencing those shaders must be manually pointed to the matching files
under `data/examples/myrqyry/`. Back up OBS scenes before installing and
prefer to stop OBS during the upgrade.
