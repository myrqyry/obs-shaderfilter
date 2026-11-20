# OBS Shaderfilter — myrqyry fork

Load your own shaders directly into OBS as filters, procedural sources and
transitions. This fork builds on [Exeldro's OBS Shaderfilter](https://github.com/exeldro/obs-shaderfilter)
and focuses on shader authoring, native OBS controls and runtime compatibility,
rather than replacing the original shader language.

[Upstream project](https://github.com/exeldro/obs-shaderfilter) ·
[Shader authoring reference](docs/SHADER-AUTHORING.md) ·
[Fork changes and evidence](docs/FORK_CLAIMS_AUDIT.md) ·
[Build checks](https://github.com/myrqyry/obs-shaderfilter/actions)

## What's different in this fork?

| Area | Fork additions and fixes |
| --- | --- |
| Procedural sources | Shaderfilter Source with configurable output width and height; no input video required for self-contained shaders. |
| Editing | File-first workflow, raw text toggle, debounced recompilation on the next video tick, and manual reload. |
| Properties | Organized source, parameter and filter-padding groups; texture source/scene selection and expanded parameter metadata handling. |
| Error handling | Compile/load error reporting, missing-file callbacks, guarded include processing and converter bounds fixes. |
| Runtime | Audio-state locking, string/buffer lifetime fixes, bounded meter values and color-format-aware render targets. |
| OBS compatibility | Runtime selection of legacy and OBS 33 image APIs, stable-version build gates, and modern/legacy Linux install locations. |
| Authoring helpers | Reusable GLSL-style math, noise, color, Oklab, animation, blur and printmaking helpers in [data/stdlib](data/stdlib/README.md). |

The core Shaderfilter Filter, Transition, OBS shader syntax and GLSL conversion
button originate upstream. Exeldro introduced the converter; this fork repairs
parts of its existing text conversion, not a new general-purpose GLSL compiler.
The property sections are ordinary OBS groups, not a custom collapsible UI.

## Using the plugin

1. Add **Shaderfilter Filter** to an existing source, **Shaderfilter Source**
   for procedural visuals, or **Shaderfilter Transition** for scene transitions.
2. Choose a shader file, or enable **Raw Shader Text** to edit inline.
3. Adjust the shader's exposed uniforms. Enable **Full Vertex Shader (.effect)**
   when supplying a complete OBS effect instead of the usual pixel-shader wrapper.
4. For filters that need extra render space (such as shadows), use Input Source Padding.
   Select Reload effect after changing an external shader file.

The [authoring reference](docs/SHADER-AUTHORING.md) covers parameter annotations,
built-in uniforms, preprocessing options and the original upstream examples.
Raw text edits compile after roughly 300 ms of inactivity, when OBS next
processes a video tick. Compile errors are logged and exposed in the properties
view when rebuilt.

## Shader collection and credits

The canonical upstream examples remain tracked at their original paths.
The fork's additional collection under `data/examples/myrqyry/` is temporarily
local-only while authorship, upstream credits and redistribution terms are
reviewed. It is intentionally absent from a fresh checkout. Existing files
have been preserved locally. See [example layout](data/examples/README.md).

Do not distribute packages from a development checkout containing unreviewed
local shader assets. The standard library remains available, but retained
helpers and notices are not a substitute for a complete attribution audit.

## Build and installation

Build against headers and libraries matching your OBS installation. Shut down
OBS and back up the plugin and its resources before replacing a working build.
This fork uses the same plugin identity as upstream; do not load both at once.

### Linux standalone build

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_OUT_OF_TREE=ON
cmake --build build --parallel
```

The module is `build/obs-shaderfilter.so`. To install to your local OBS profile:

```sh
cmake --build build --target install-user
```

The user-install target copies the module to the modern root location and
the legacy `bin/64bit/` location. It archives specifically enumerated old
example paths without overwriting existing backups. It also copies the local
data directory, including ignored local assets. Use a clean checkout for
distribution. Back up custom shaders and scenes before installing.

The original in-tree OBS build is also supported: place the repository in
`plugins/obs-shaderfilter` and include it in the OBS CMake build. For Windows
and macOS see the project's [build workflows](.github/workflows/build.yml).
Upstream release downloads do not contain these fork changes.

## Compatibility and verification

The Linux compatibility workflow includes OBS 32.2.2, OBS 33.0.1 and a
development-branch early-warning build. Runtime code resolves the old image
helpers for OBS 28–32 and the newer image API for OBS 33+, with missing-helper
guards. Build coverage is not exhaustive GPU or interactive UI validation.

The November 3 OBS 33 integration checkpoint passed the readiness contract,
29 Python tests and a fresh Linux build. Earlier isolated libobs pixel tests
covered the local shader collection. Those effect-specific tests are historical
evidence and some now require the excluded assets. No clean-checkout full
effect-suite qualification is claimed after the attribution cleanup.

```sh
python3 scripts/test-obs33-readiness.py
```

Known limitations: the include loader can skip a repeated non-circular include;
the GLSL converter cannot translate arbitrary shaders or function-like macros;
property refresh may still rebuild the view. Standalone experiments in
`experiments/` are not integrated WebGPU or GLSLP plugin features.
See the [claim audit](docs/FORK_CLAIMS_AUDIT.md) and
[worktree handoff](docs/WORKTREE_HANDOFF.md) for historical evidence.

## License and upstream

See [LICENSE](LICENSE). The original plugin, its shader language integration
and canonical examples are credited to Exeldro and upstream contributors.
Individual shader adaptations may have separate copyright and license terms.

For upstream issues and releases visit
[Exeldro's repository](https://github.com/exeldro/obs-shaderfilter).
For fork-specific issues use [this fork's issue tracker](https://github.com/myrqyry/obs-shaderfilter/issues).

Support the upstream author: [Exeldro's donation page](https://www.paypal.me/exeldro).
