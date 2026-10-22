#!/usr/bin/env python3
"""Compile older user-authored include libraries and GPU-test the existing 3D panel.

Uses ShaderFilter's *real* .shader effect wrapper, extracted by verify_stdlib,
rather than a standalone GLSL/FX substitute. This does not install OBS.
"""
from pathlib import Path
import re
import shlex
import subprocess
import tempfile
import verify_stdlib as obs

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / "docs/history/legacy-shaders-20261021"

CASES = {
    "blending_modes.shader": (
        "float4 mainImage(VertData v_in):TARGET {"
        "return blend(16,float4(0.2,0.4,0.5,1.0),"
        "float4(0.9,0.6,0.2,0.5));}"
    ),
    "lib_color.shader": (
        "float4 mainImage(VertData v_in):TARGET {"
        "return float4(blendOverlay(rgb2hsv(float3(0.4,0.5,0.8)),"
        "float3(0.3,0.6,0.8)),1.0);}"
    ),
    "lib_math.shader": (
        "float4 mainImage(VertData v_in):TARGET {"
        "float n=noise(v_in.uv*5.0)+map(v_in.uv.x,0.0,1.0,0.1,0.5);"
        "return float4(n,rand2(v_in.uv),0.5,1.0);}"
    ),
    "lib_spatial.shader": (
        "float4 mainImage(VertData v_in):TARGET {"
        "float2 uv=zoomUV(fixAspect(rotateUV(v_in.uv,0.25,"
        "float2(0.5,0.5)),uv_size),2.0,float2(0.5,0.5));"
        "return float4(uv,0.2,1.0);}"
    ),
}


def main():
    with tempfile.TemporaryDirectory(prefix="obs-legacy-authored-") as temporary:
        tmp = Path(temporary)
        flags = shlex.split(
            subprocess.check_output(
                ["pkg-config", "--cflags", "--libs", "libobs"], text=True
            )
        )
        obs.NATIVE_BINARY = tmp / "compile"
        subprocess.run(
            [
                "cc",
                "-O2",
                str(ROOT / "tests/native_stdlib_compile.c"),
                "-o",
                str(obs.NATIVE_BINARY),
                *flags,
            ],
            check=True,
        )
        for filename, body in CASES.items():
            archive = ARCHIVE / filename
            assert archive.is_file(), f"Missing historical original: {archive}"
            obs.compile_case("legacy/" + filename, archive.read_text() + "\n" + body, archive)

        panel = ROOT / "data/examples/3d-panel.shader"
        effect = tmp / "panel.effect"
        effect.write_text(
            "#define OPENGL 1\n"
            + obs.template("begin")
            + obs.expand_text(panel.read_text(), panel).replace("[loop]", "")
            + "\n"
            + obs.template("end")
        )
        include_dir = subprocess.check_output(
            ["pkg-config", "--variable=includedir", "libobs"], text=True
        ).strip()
        libs = subprocess.check_output(
            ["pkg-config", "--libs", "libobs"], text=True
        ).split()
        probe = tmp / "pixel-probe"
        subprocess.run(
            [
                "g++",
                "-std=c++17",
                "-O2",
                "-Wall",
                "-Wextra",
                "-I" + str(Path(include_dir) / "obs"),
                str(ROOT / "tests/native_shader_pixel_probe.cpp"),
                "-o",
                str(probe),
                *libs,
            ],
            check=True,
        )
        args = [
            str(probe), str(effect), "brightness", "0.55", "1.45",
            "scale=0.8", "tilt_y_deg=15", "tilt_x_deg=5"
        ]
        run = subprocess.run(args, capture_output=True, text=True, timeout=35)
        match = re.search(
            r"GPU_READBACK_PASS=1 CONTROL=brightness "
            r"CHANGED=(\d+) CHANGED_FROM_INPUT=(\d+) "
            r"ALPHA_CHANGED=(\d+) RGB_SUM=(\d+)", run.stdout
        )
        assert (
            run.returncode == 0 and match is not None
            and int(match.group(1)) > 1000
            and int(match.group(2)) > 1000
            and int(match.group(4)) > 0
        ), (run.stdout + "\n" + run.stderr)[-2000:]
        print("PASS 3d-panel.shader wrapped native GPU brightness response " + match.group(0))
        print("LEGACY_AUTHOR_SHADER_PASS=1 LIBRARIES=4 PANEL_GPU=1", flush=True)


if __name__ == "__main__":
    main()
