#!/usr/bin/env python3
"""Real native libobs/OpenGL regression tests for a revived Bitmap25 filter."""
from pathlib import Path
import re
import hashlib
import shlex
import subprocess
import tempfile
import shutil
import verify_stdlib as wrapper

ROOT = Path(__file__).resolve().parents[1]
SHADER = ROOT / "data/examples/myrqyry/bitmap-glyph-motion.shader"
REPORT = re.compile(
    r"GPU_READBACK_PASS=1 CONTROL=\S+ CHANGED=(\d+) "
    r"CHANGED_FROM_INPUT=(\d+) ALPHA_CHANGED=(\d+) RGB_SUM=(\d+)"
)


def main():
    assert SHADER.is_file(), "RED: bitmap-glyph-motion shader is absent"
    text = SHADER.read_text()
    # Exercise the actual user delivery boundary: ONE .shader file copied
    # to an arbitrary Downloads-like directory outside the repository.
    # The previous test expanded a repo-local #include and therefore
    # succeeded even though OBS failed to load the downloaded file.
    assert "#include" not in text, (
        "Single-file shader must not depend on paths relative to the repository"
    )
    assert "blendColor(" in text and "blendHue(" in text
    assert "GlyphMask(" in text and "BitmaskFor(" in text
    # Immutable fingerprint of all seven original five-step bitmask sequences.
    # Changes to glyph art must be intentional, never a casual style cleanup.
    rows = []
    for _, body in re.findall(r"if \(glyphSet == (\d)\) \{(.*?)\n    \}", text, re.S):
        rows.append([int(n) for n in re.findall(r"return (\d+);", body)])
    assert len(rows) == 7 and all(len(row) == 5 for row in rows)
    assert hashlib.sha256(repr(rows).encode()).hexdigest() == (
        "3dea22e7f1129c589d81d92bf27935c44a8325f08a9fca32f189947fc05ea812"
    ), "Original bitmap25 5x5 glyph art unexpectedly changed"
    with tempfile.TemporaryDirectory(prefix="obs-bitmap-glyph-") as t:
        tmp = Path(t)
        loose_dir = tmp / "Downloads"
        loose_dir.mkdir()
        loose_shader = loose_dir / SHADER.name
        shutil.copyfile(SHADER, loose_shader)
        assert loose_shader.read_bytes() == SHADER.read_bytes()
        effect = tmp / "filter.effect"
        # Faithful plugin load path: ShaderFilter prepends/appends its
        # compiled effect template to the raw bytes of the selected file;
        # the plugin's include resolver is relative to *this file*, not
        # to the repo. With no includes, no preprocessing can conceal
        # missing runtime dependencies.
        effect.write_text(
            "#define OPENGL 1\n"
            + wrapper.template("begin")
            + loose_shader.read_text().replace("[loop]", "")
            + "\n"
            + wrapper.template("end")
        )
        includedir = subprocess.check_output(
            ["pkg-config", "--variable=includedir", "libobs"], text=True
        ).strip()
        libs = subprocess.check_output(["pkg-config", "--libs", "libobs"], text=True).split()
        probe = tmp / "native-pixel-probe"
        subprocess.run(
            ["g++", "-std=c++17", "-O2", "-Wall", "-Wextra",
             "-I" + str(Path(includedir) / "obs"),
             str(ROOT / "tests/native_shader_pixel_probe.cpp"),
             "-o", str(probe), *libs],
            check=True, capture_output=True
        )
        cases = [
            ("Mix", 0, 1, [], 300, 0),  # pass-through to full effect
            ("Cell_Pixels", 6, 14, ["Mix=1"], 100, None),
            ("Glyph_Set", 0, 4, ["Mix=1"], 100, None),
            ("Blend_Mode", 5, 6, ["Mix=1", "Ink_Mode=1"], 50, None),
            ("elapsed_time", 0, 6, ["Mix=1", "Animate=1", "Motion_Pixels=20"], 100, None),
            ("Motion_Mode", 0, 1,
             ["Mix=1", "Animate=1", "Motion_Pixels=20", "elapsed_time=4"],
             100, None),
            ("Ink_Mode", 0, 2, ["Mix=1"], 100, None),
            ("Ink_Opacity", 0, 1, ["Mix=1"], 100, None),
            ("Background_Amount", 0, 1, ["Mix=1"], 100, None),
            ("Low_Threshold", 0, 0.65, ["Mix=1"], 100, None),
        ]
        for partial in (False, True):
            for name, a, b, options, min_changed, max_identity in cases:
                cmd = [str(probe), str(effect), name, str(a), str(b)]
                if partial:
                    cmd.append("partial-alpha")
                cmd.extend(options)
                run = subprocess.run(cmd, capture_output=True, text=True, timeout=35)
                match = REPORT.search(run.stdout)
                assert run.returncode == 0 and match, (
                    f"{name} partial={partial}: {(run.stdout+run.stderr)[-1200:]}"
                )
                changed, original, alpha, sum_rgb = map(int, match.groups())
                assert changed >= min_changed, (name, partial, changed, run.stdout)
                # The effect must not alter source transparency, even at full mix.
                assert alpha == 0, (name, partial, alpha, run.stdout)
                if max_identity is not None:
                    assert original == max_identity, (name, partial, original, run.stdout)
                assert sum_rgb > 0, (name, partial, run.stdout)
                print(f"PASS {name} partial={partial} changed={changed} alpha={alpha}", flush=True)
        print(f"BITMAP_GLYPH_GPU_PASS=1 CASES={len(cases)*2}", flush=True)


if __name__ == "__main__":
    main()
