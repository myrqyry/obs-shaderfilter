#!/usr/bin/env python3
"""Probe a standalone Glyph Garden .shader, including all nine motion modes.

The source is first copied to a bare Downloads-like directory; no includes
are expanded. The actual-plugin acceptance test is a separate executable.
"""
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tempfile
import verify_stdlib as wrapped

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "data/examples/myrqyry/glyph-garden.shader"
REPORT = re.compile(r"GPU_READBACK_PASS=1 CONTROL=\S+ CHANGED=(\d+) CHANGED_FROM_INPUT=(\d+) ALPHA_CHANGED=(\d+) RGB_SUM=(\d+)")


def verify_masks(contents):
    # Each family has exactly five visually authored bitmap numbers <= 25 bits.
    rows = re.findall(r"if \(family == ([0-5])\) \{(.*?)\n    \}", contents, re.S)
    assert [int(i) for i, _ in rows] == list(range(6)), rows
    for family, body in rows:
        bitmasks = [int(b) for b in re.findall(r"if \(tone == [1-5]\) return (\d+);", body)]
        assert len(bitmasks) == 5, (family, bitmasks)
        assert all(0 < b < (1 << 25) for b in bitmasks)
        assert len(set(bitmasks)) >= 4, (family, bitmasks)
    print("PASS GLYPH_FAMILIES=6 GLYPH_MASKS=30", flush=True)


def main():
    text = SOURCE.read_text()
    assert "#include" not in text, "Self-contained .shader cannot depend on repository"
    assert "float4 mainImage(VertData v_in):TARGET" in text
    verify_masks(text)

    with tempfile.TemporaryDirectory(prefix="garden-download-test-") as location:
        folder = Path(location)
        detached = folder / "Downloads"
        detached.mkdir()
        candidate = detached / SOURCE.name
        shutil.copy2(SOURCE, candidate)
        assert SOURCE.read_bytes() == candidate.read_bytes()
        effect = folder / "standalone.effect"
        effect.write_text("#define OPENGL 1\n" +
                          wrapped.template("begin") +
                          candidate.read_text().replace("[loop]", "") +
                          "\n" + wrapped.template("end"))
        includes = subprocess.check_output(
            ["pkg-config", "--variable=includedir", "libobs"], text=True
        ).strip()
        libs = shlex.split(
            subprocess.check_output(["pkg-config", "--libs", "libobs"], text=True)
        )
        probe = folder / "native-pixel-probe"
        subprocess.run([
            "g++", "-std=c++17", "-O2", "-Wall", "-Wextra",
            "-I" + str(Path(includes) / "obs"),
            str(ROOT / "tests/native_shader_pixel_probe.cpp"),
            "-o", str(probe), *libs
        ], check=True, capture_output=True)
        tests = [
            ("Mix", 0, 1, [], 500, True),
            ("Gap_Pixels", 0, 18, ["Glyph_Pixels=10"], 500, False),
            ("Glyph_Pixels", 6, 19, ["Gap_Pixels=7"], 500, False),
            ("Glyph_Set_A", 0, 5, ["Dual_Set=0"], 100, False),
            ("Glyph_Set_B", 0, 5, ["Dual_Set=1", "Tone_Split=0.20"], 100, False),
            ("Dual_Set", 0, 1, ["Glyph_Set_B=5", "Tone_Split=0.25"], 100, False),
            ("Tone_Split", 0.1, 0.9, ["Dual_Set=1", "Glyph_Set_B=5"], 100, False),
            ("Grid_Line_Opacity", 0, 1, ["Gap_Pixels=12"], 100, False),
            ("Random_Quarter_Turns", 0, 1, ["Dual_Set=0", "Glyph_Set_A=3"], 100, False),
            ("Ink_Mode", 0, 3, [], 100, False),
            ("Blend_Mode", 5, 6, ["Ink_Mode=1"], 100, False),
            ("Background_Source", 0, 1, [], 500, False),
            ("Motion_Pixels", 0, 16, ["Animate=1", "Motion_Mode=4", "elapsed_time=4"], 100, False),
            ("Wave_Length", 2, 18, ["Animate=1", "Motion_Mode=4", "elapsed_time=4"], 100, False),
            ("Snap_Rate", 2, 16, ["Animate=1", "Motion_Mode=8", "elapsed_time=4.31"], 100, False),
            ("elapsed_time", 0, 4, ["Animate=1", "Motion_Mode=1", "Motion_Pixels=20"], 100, False),
        ]
        for mode in range(1, 10):
            tests.append((
                "Motion_Mode", 0, mode,
                ["Animate=1", "elapsed_time=4.27", "Gap_Pixels=12",
                 "Motion_Pixels=12", "Glyph_Pixels=11"],
                100, False,
            ))
        passed = 0
        for partial in (False, True):
            for parameter, a, b, settings, needed, identity in tests:
                cmd = [str(probe), str(effect), parameter, str(a), str(b)]
                if partial:
                    cmd.append("partial-alpha")
                cmd.extend(settings)
                run = subprocess.run(cmd, capture_output=True, text=True, timeout=40)
                found = REPORT.search(run.stdout)
                assert run.returncode == 0 and found, (
                    parameter, a, b, partial, (run.stdout+run.stderr)[-1500:]
                )
                changed, different, alpha, brightness = map(int, found.groups())
                assert changed >= needed, (parameter, a, b, partial, changed)
                assert brightness > 0
                assert alpha == 0, (parameter, a, b, partial, alpha)
                if identity:
                    assert different == 0, ("Mix=0 broke passthrough", different)
                passed += 1
                print("PASS", parameter, f"{a}->{b}", "alpha" if partial else "opaque",
                      f"changed={changed}", flush=True)
        print(f"GLYPH_GARDEN_NATIVE_GPU_PASS=1 CASES={passed}", flush=True)


if __name__ == "__main__":
    main()
