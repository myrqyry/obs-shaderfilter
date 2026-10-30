#!/usr/bin/env python3
"""Compile and render PixelOE filter ports through native libobs/OpenGL."""
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
import verify_stdlib as wrapped

SHADERS = {
    "pixeloe-outline": ("Thickness", "0", "3", ["Pixel_Size=6"]),
    "pixeloe-pixelize": ("Pixel_Size", "2", "8", []),
}
EXTRA_CASES = [
    ("pixeloe-pixelize", "Denoise_Strength", "0", "1", ["Pixel_Size=6"]),
    ("pixeloe-pixelize", "Color_Quantization", "0", "1",
     ["Pixel_Size=6", "Dither_Strength=0"]),
    ("pixeloe-pixelize", "Dither_Strength", "0", "1",
     ["Pixel_Size=6", "Color_Quantization=1", "Color_Levels=5"]),
]
REPORT = re.compile(
    r"GPU_READBACK_PASS=1 CONTROL=\S+ CHANGED=(\d+) "
    r"CHANGED_FROM_INPUT=(\d+) ALPHA_CHANGED=(\d+) RGB_SUM=(\d+)"
)


def main():
    with tempfile.TemporaryDirectory(prefix="pixeloe-native-") as temporary:
        temp = Path(temporary)
        compiler = temp / "native-effect-compiler"
        probe = temp / "native-pixel-probe"
        cflags = shlex.split(subprocess.check_output(
            ["pkg-config", "--cflags", "--libs", "libobs"], text=True
        ))
        subprocess.run([
            "cc", "-O2", "-Wall", "-Wextra",
            str(ROOT / "tests/native_stdlib_compile.c"), "-o", str(compiler),
            *cflags,
        ], check=True)
        includes = subprocess.check_output(
            ["pkg-config", "--variable=includedir", "libobs"], text=True
        ).strip()
        libs = shlex.split(subprocess.check_output(
            ["pkg-config", "--libs", "libobs"], text=True
        ))
        subprocess.run([
            "g++", "-std=c++17", "-O2", "-Wall", "-Wextra",
            "-I" + str(Path(includes) / "obs"),
            str(ROOT / "tests/native_shader_pixel_probe.cpp"),
            "-o", str(probe), *libs,
        ], check=True)

        for name, (control, before, after, presets) in SHADERS.items():
            shader = ROOT / "data/examples/myrqyry" / f"{name}.shader"
            source = shader.read_text()
            assert "#include" not in source, f"{name} must be standalone"
            assert "float4 mainImage(VertData v_in) : TARGET" in source
            effect = temp / f"{name}.effect"
            effect.write_text(
                "#define OPENGL 1\n" + wrapped.template("begin")
                + source.replace("[loop]", "") + "\n"
                + wrapped.template("end")
            )
            result = subprocess.run(
                [str(compiler), str(effect)], capture_output=True, text=True,
                timeout=40,
            )
            assert result.returncode == 0, (name, result.stdout, result.stderr)
            print(f"PASS {name} native effect compile", flush=True)

            cases = [(control, before, after, presets)]
            cases.extend(case[1:] for case in EXTRA_CASES if case[0] == name)
            for parameter, value_before, value_after, case_presets in cases:
                for partial_alpha in (False, True):
                    command = [str(probe), str(effect), parameter,
                               value_before, value_after]
                    if partial_alpha:
                        command.append("partial-alpha")
                    command.extend(case_presets)
                    run = subprocess.run(
                        command, capture_output=True, text=True, timeout=40
                    )
                    report = REPORT.search(run.stdout)
                    assert run.returncode == 0 and report, (
                        name, parameter, partial_alpha, run.stdout, run.stderr
                    )
                    changed, _, alpha_changed, rgb_sum = map(
                        int, report.groups()
                    )
                    assert changed > 0, (name, parameter, report.groups())
                    assert alpha_changed == 0, (name, parameter, report.groups())
                    assert rgb_sum > 0, (name, parameter, report.groups())
                    print(
                        f"PASS {name} {parameter} {value_before}->{value_after} "
                        f"{'partial-alpha' if partial_alpha else 'opaque'} "
                        f"changed={changed}", flush=True,
                    )
        count = 2 * (len(SHADERS) + len(EXTRA_CASES))
        print(f"PIXEL_OE_NATIVE_GPU_PASS=1 CASES={count}", flush=True)


if __name__ == "__main__":
    main()
