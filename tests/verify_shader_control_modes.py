#!/usr/bin/env python3
"""Run repaired selector-like controls through real libobs/OpenGL readback.

This verifies shader outcomes, not the interactive OBS Properties panel. The
numeric scalar types stay unchanged to preserve old OBS profile value types.
"""
from pathlib import Path
import re
import subprocess
import tempfile

import verify_stdlib as stdlib

ROOT = Path(__file__).resolve().parents[1]
SHADERS = ROOT / "data/examples/myrqyry/noisemaker-ports"
# (shader, parameter, before, after, auxiliary controls)
CASES = (
    ("nm_edge.shader", "kernel", 1, 2, ("blend=6", "amount=100", "level=50")),
    ("nm_edge.shader", "blend", 6, 8, ("kernel=1", "amount=100")),
    ("nm_edge.shader", "invert", 0, 1, ("kernel=1", "amount=100")),
    ("nm_edge.shader", "channel", 0, 1, ("kernel=1", "amount=100")),
    ("nm_edge.shader", "contourSide", 0, 1, ("kernel=2", "amount=100", "level=50")),
    ("nm_edge.shader", "size", -1, 1, ("kernel=1", "amount=100")),
    ("nm_sine.shader", "colorMode", 0, 1, ()),
    ("nm_glowingEdge.shader", "sobelMetric", 0, 3, ()),
)

def main():
    with tempfile.TemporaryDirectory(prefix="shader-control-modes-") as folder:
        tmp = Path(folder)
        probe = tmp / "probe"
        includedir = subprocess.check_output(
            ["pkg-config", "--variable=includedir", "libobs"], text=True).strip()
        libs = subprocess.check_output(
            ["pkg-config", "--libs", "libobs"], text=True).split()
        subprocess.run([
            "g++", "-std=c++17", "-O2", "-Wall", "-Wextra",
            "-I" + str(Path(includedir) / "obs"),
            str(ROOT / "tests/native_shader_pixel_probe.cpp"),
            "-o", str(probe), *libs], check=True)
        for idx, (name, control, a, b, preset) in enumerate(CASES):
            shader = SHADERS / name
            source = ("#define OPENGL 1\n" + stdlib.template("begin") +
                stdlib.expand_text(shader.read_text(), shader).replace("[loop]", "") +
                "\n" + stdlib.template("end"))
            effect = tmp / f"shader-{idx}.effect"
            effect.write_text(source)
            result = subprocess.run([
                str(probe), str(effect), control, str(a), str(b), *preset],
                text=True, capture_output=True, timeout=20)
            match = re.search(
                r"GPU_READBACK_PASS=1 CONTROL=\S+ CHANGED=(\d+) "
                r"CHANGED_FROM_INPUT=(\d+) ALPHA_CHANGED=(\d+) RGB_SUM=(\d+)",
                result.stdout)
            if result.returncode or match is None:
                raise AssertionError(f"{name}:{control} failed to compile/render:\n"
                                     f"{result.stdout[-900:]}\n{result.stderr[-900:]}")
            changed, baseline, alpha, rgb = map(int, match.groups())
            if changed < 20 or rgb == 0 or alpha != 0:
                raise AssertionError(
                    f"{name}:{control} not visibly distinct ({a} vs {b}): "
                    f"changed={changed}, from input={baseline}, "
                    f"alpha_changed={alpha}, rgb_sum={rgb}")
            print(f"REAL_CONTROL_GPU_PASS {name}:{control} {a}->{b} "
                  f"changed={changed} alpha={alpha}", flush=True)
    print(f"SHADER_CONTROL_MODE_GPU_PASS=1 CASES={len(CASES)}")

if __name__ == "__main__":
    main()
