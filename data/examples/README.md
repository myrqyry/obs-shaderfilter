# Shaderfilter examples: upstream and myrqyry

This directory deliberately retains the **164 original files** from
[exeldro/obs-shaderfilter](https://github.com/exeldro/obs-shaderfilter)
at their canonical upstream paths (the `.shader` and `.effect` files directly
inside `data/examples/`). The original files are byte-identical to our
upstream `master` snapshot used for this split. Keeping their paths unchanged
preserves existing upstream-based OBS presets and makes future upstream
synchronization straightforward.

## Local additions — attribution review

The fork's `myrqyry/` folder is ignored by Git and excluded from fresh
checkouts while authorship and redistribution terms are reviewed. Existing
local files remain available; they have not been deleted. Do not publish
a package built from a local checkout containing these unreviewed assets.
The original upstream examples retain their canonical paths.

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
