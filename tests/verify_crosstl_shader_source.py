#!/usr/bin/env python3
"""Optional real installed-Shaderfilter standalone Source integration test.

Uses a disposable libobs session. Does not modify the installed plugin,
running OBS instance, scenes, profiles or shader directories.
"""
from __future__ import annotations

import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
NATIVE = ROOT / "tests/native_crosstl_shader_source_probe.cpp"
SHADER = ROOT / "data/examples/myrqyry/glyphfield-soft-register-procedural.shader"
PLUGIN_DIR = Path.home() / ".config/obs-studio/plugins/obs-shaderfilter"
MODULE = Path(os.environ.get("OBS_SHADERFILTER_MODULE", PLUGIN_DIR / "bin/64bit/obs-shaderfilter.so"))
DATA = Path(os.environ.get("OBS_SHADERFILTER_DATA", PLUGIN_DIR / "data"))


def main() -> None:
    if not NATIVE.is_file() or not MODULE.is_file() or not DATA.is_dir() or not SHADER.is_file():
        raise RuntimeError("Missing native probe, installed OBS Shaderfilter, plugin data or generated shader")
    inc = subprocess.check_output(["pkg-config", "--variable=includedir", "libobs"], text=True).strip()
    libs = shlex.split(subprocess.check_output(["pkg-config", "--libs", "libobs"], text=True))
    with tempfile.TemporaryDirectory(prefix="crossgl-obs-plugin-") as folder:
        exe = str(Path(folder) / "shader-source-check")
        subprocess.run(["g++", "-std=c++20", "-O2", "-Wall", "-Wextra",
                        "-I" + inc + "/obs", str(NATIVE), "-o", exe, *libs], check=True)
        test = subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 1280x720x24", "timeout", "35",
                               exe, str(MODULE), str(DATA), str(SHADER)],
                              text=True, capture_output=True, timeout=55)
        messages = test.stdout + "\n" + test.stderr
        if test.returncode != 0 or "CROSSTL_SHADER_SOURCE_PLUGIN_PASS=1" not in messages:
            raise RuntimeError("Real Shaderfilter source integration failed:\n" + messages[-4500:])
        dim = re.search(r"SOURCE_DIMENSIONS=(\d+)x(\d+) PARAM_CONTROL=(\d+) ERROR=(.*)", messages)
        pixels = re.search(r"SOURCE_RENDER_INPUT_SUM=(\d+) OUTPUT_SUM=(\d+) PIXEL_DIFF=(\d+)", messages)
        if not dim or not pixels or dim.group(1, 2, 3) != ("256", "144", "1"):
            raise RuntimeError("Missing or invalid real source/controls evidence:\n" + messages[-2000:])
        if int(pixels.group(1)) <= 10000 or int(pixels.group(2)) <= 10000 or int(pixels.group(3)) <= 500:
            raise RuntimeError("Source rendered too few meaningful pixels")
        if dim.group(4):
            raise RuntimeError("Shaderfilter reported error: " + dim.group(4))
        print(f"CROSSTL_SHADER_SOURCE_PLUGIN_PASS=1 dimensions=256x144 "
              f"changed={pixels.group(3)} module={MODULE.name}")


if __name__ == "__main__":
    main()
