#!/usr/bin/env python3
"""Real libobs/OpenGL render checks of the potatoFX Oklab palette adaptation.

Checks live shader controls and preserves alpha; NOT ReShade/HDR visual parity.
"""
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import verify_stdlib as obs

ROOT = Path(__file__).resolve().parents[1]
SHADER = ROOT / "data/examples/myrqyry/potatofx-ports/palette_harmony.shader"
# Different values must produce meaningfully different real GPU pixels.
CONTROLS = (
    ("palette_type", 0, 4),
    ("palette_type", 2, 3),
    ("num_colors", 2, 12),
    ("palette_balance", 0.15, 0.85),
    ("dither_strength", 0.0, 0.1),
    ("desaturate_highlights", 0, 1),
    ("effect_mix", 0, 1),
)
PATTERN = re.compile(
    r"GPU_READBACK_PASS=1 CONTROL=\S+ CHANGED=(\d+) "
    r"CHANGED_FROM_INPUT=(\d+) ALPHA_CHANGED=(\d+) RGB_SUM=(\d+)"
)

def main():
    assert SHADER.is_file(), "palette_harmony.shader was not implemented"
    code = SHADER.read_text()
    assert "GimleLarpes/potatoFX" in code
    assert "float4 mainImage(VertData v_in)" in code
    assert (SHADER.parent / "POTATOFX-LICENSE.txt").is_file()
    with tempfile.TemporaryDirectory(prefix="potatofx-native-") as tmp:
        work = Path(tmp)
        probe = work / "probe"
        inc = subprocess.check_output(
            ["pkg-config", "--variable=includedir", "libobs"], text=True
        ).strip()
        libs = subprocess.check_output(
            ["pkg-config", "--libs", "libobs"], text=True
        ).split()
        subprocess.run([
            "g++", "-std=c++17", "-O2", "-Wall", "-Wextra",
            "-I" + str(Path(inc) / "obs"),
            str(ROOT / "tests/native_shader_pixel_probe.cpp"),
            "-o", str(probe), *libs
        ], check=True)
        effect = work / "palette.effect"
        effect.write_text("#define OPENGL 1\n" + obs.template("begin") +
                          obs.expand_text(code, SHADER).replace("[loop]", "") +
                          "\n" + obs.template("end"))
        failures = []
        for name, a, b in CONTROLS:
            for alpha_pattern in (False, True):
                args = [str(probe), str(effect), name, str(a), str(b)]
                if alpha_pattern:
                    args.append("partial-alpha")
                if name == "palette_balance":
                    args.append("palette_type=2")
                if name == "num_colors":
                    args.append("dither_strength=0")
                run = subprocess.run(args, text=True, capture_output=True, timeout=25)
                match = PATTERN.search(run.stdout)
                if not match or run.returncode:
                    failures.append((name, "no native GPU output", (run.stderr + run.stdout)[-700:]))
                    print("FAIL", name, "alpha" if alpha_pattern else "opaque", (run.stderr + run.stdout)[-600:], flush=True)
                    continue
                changed, from_input, alpha_changed, rgb_sum = map(int, match.groups())
                ok = (changed > 20 and alpha_changed == 0 and rgb_sum > 0 and
                      (name != "effect_mix" or from_input == 0))
                if name == "num_colors" and not alpha_pattern:
                    # The fixture spans only part of the lightness range, so
                    # 12 possible levels need not all occur; never exceed 12.
                    exact = re.search(r"DISTINCT_FIRST=(\d+) DISTINCT_SECOND=(\d+)",run.stdout)
                    if exact:
                        first_count, second_count = map(int, exact.groups())
                        ok = ok and first_count == 2 and 2 < second_count <= 12
                    else:
                        ok = False
                print("PASS" if ok else "FAIL", name,
                      "partial-alpha" if alpha_pattern else "opaque",
                      "changed", changed, "passthrough_diff", from_input,
                      "alpha_changed", alpha_changed, flush=True)
                if not ok:
                    failures.append((name, "bad pixel/control/alpha result", str(match.groups())))
        print("POTATOFX_PALETTE_NATIVE_GPU_PASS=", int(not failures),
              "CASES=", 2 * len(CONTROLS), "FAILED=", len(failures))
        if failures:
            sys.exit(1)

if __name__ == "__main__":
    main()
