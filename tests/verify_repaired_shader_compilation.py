#!/usr/bin/env python3
"""Compile every parameter-repaired legacy effect in a real libobs/OpenGL context."""
from pathlib import Path
import shlex
import subprocess
import tempfile

import verify_stdlib as stdlib

ROOT = Path(__file__).resolve().parents[1]
EFFECTS = (
    "emboss_color.shader",
    "fire-3.effect",
    "smart_denoise.shader",
    "displacement_map_advanced.shader",
    "displacement_map_advanced_invert.shader",
)


def main():
    with tempfile.TemporaryDirectory(prefix="shader-defaults-native-") as folder:
        dest = Path(folder)
        native = dest / "native-compiler"
        flags = shlex.split(subprocess.check_output(
            ["pkg-config", "--cflags", "--libs", "libobs"], text=True))
        subprocess.run([
            "cc", "-O2", "-Wall", "-Wextra",
            str(ROOT / "tests/native_stdlib_compile.c"),
            "-o", str(native), *flags], check=True)
        for file in EFFECTS:
            path = ROOT / "data/examples" / file
            source = path.read_text()
            if file.endswith(".shader"):
                source = ("#define OPENGL 1\n" + stdlib.template("begin") +
                          stdlib.expand_text(source, path).replace("[loop]", "") +
                          "\n" + stdlib.template("end"))
            wrapped = dest / f"{file}.effect"
            wrapped.write_text(source)
            outcome = subprocess.run(
                [str(native), str(wrapped)], text=True, capture_output=True, timeout=20)
            if outcome.returncode:
                raise AssertionError(
                    f"Native libobs shader compilation failed for {file}: "
                    f"{(outcome.stderr + outcome.stdout)[-1500:]}")
            print(f"LEGACY_SHADER_NATIVE_COMPILE_PASS {file}", flush=True)
    print(f"REPAIRED_DEFAULT_NATIVE_COMPILE_PASS=1 COUNT={len(EFFECTS)}")


if __name__ == "__main__":
    main()
