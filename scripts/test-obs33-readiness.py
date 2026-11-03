#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
compat = (root / ".github/workflows/compatibility.yml").read_text()
assert "OBS 33.0.1 stable" in compat
assert "obs_ref: 33.0.1" in compat
assert "ubuntu-26.04" in compat
assert "libopengl-dev" in compat

source = (root / "obs-shaderfilter.c").read_text()
for symbol in ("gs_image_file_ex_init", "gs_image_file4_init", "obs_get_version()"):
    assert symbol in source
assert "os_dlsym" in source

build = (root / ".github/workflows/build.yml").read_text()
assert "package\\obs-shaderfilter\\obs-shaderfilter.dll" in build
assert "package\\obs-plugins" in build

cmake = (root / "CMakeLists.txt").read_text()
assert 'copy $<TARGET_FILE:${PROJECT_NAME}> ${OBS_USER_PLUGIN_DIR}/${PROJECT_NAME}.so' in cmake
assert '${OBS_USER_PLUGIN_DIR}/bin/64bit/${PROJECT_NAME}.so' in cmake

installer = (root / "installer.iss.in").read_text()
assert "{commonappdata}\\obs-studio\\plugins\\obs-shaderfilter" in installer
assert 'DestDir: "{app}\\obs-plugins"' in installer
print("PASS: shaderfilter has stable OBS33 coverage, runtime ABI bridge, and modern+legacy Windows install paths")

assert "fetch-depth: 0" in compat, "OBS master canary needs version tags/history for git describe"
assert "python3 obs-studio/plugins/obs-shaderfilter/scripts/test-obs33-readiness.py" in compat, (
    "readiness contract must execute in compatibility CI"
)
