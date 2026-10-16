#!/usr/bin/env python3
"""Native libobs/OpenGL pixel readback for OBS adaptations of MPV anime shaders.

Exercise compiled OBS Shaderfilter wrapper with the same graphics path used
for Noisemaker ports. This is not output parity against mpv's renderer.
"""
from pathlib import Path
import subprocess
import tempfile
import re
import sys
import verify_stdlib as obs
repo = Path(__file__).resolve().parents[1]
shaders = repo / "data/examples/mpv-anime-ports"
cases = {
    "anime_line_thinner": ("blend_factor", 0, 1),
    "anime_bilateral_mean": ("blend_factor", 0, 1),
    "cas_luma_sharpen": ("amount", 0, 1),
    "static_luma_grain": ("strength", 0, 256),
    "static_chroma_grain": ("strength", 0, 256),
}
assert {p.stem for p in shaders.glob("*.shader")} == set(cases), "untested shaders"
assert (shaders / "MPV-ANIME-LICENSE.txt").is_file()
with tempfile.TemporaryDirectory(prefix="mpv-anime-gpu-") as dir:
    target = Path(dir)
    probe = target / "native-pixel-probe"
    inc = subprocess.check_output(
        ["pkg-config", "--variable=includedir", "libobs"], text=True).strip()
    libs = subprocess.check_output(["pkg-config", "--libs", "libobs"], text=True).split()
    subprocess.run(["g++", "-std=c++17", "-O2", "-Wall", "-Wextra",
        "-I" + str(Path(inc) / "obs"), str(repo/"tests/native_shader_pixel_probe.cpp"),
        "-o", str(probe), *libs], check=True)
    failures = []
    for name, (uniform, a, b) in cases.items():
        shader = shaders / f"{name}.shader"
        code = shader.read_text()
        assert "Chinna95P/mpv-anime-build" in code
        assert "float4 mainImage(VertData v_in)" in code
        effect_src = "#define OPENGL 1\n" + obs.template("begin") + (
            obs.expand_text(code, shader).replace("[loop]", "")) + "\n" + obs.template("end")
        effect = target/f"{name}.effect"
        effect.write_text(effect_src)
        process = subprocess.run([str(probe), str(effect), uniform, str(a), str(b)],
            capture_output=True, text=True, timeout=25)
        match = re.search(
            r"GPU_READBACK_PASS=1 CONTROL=\S+ CHANGED=(\d+) CHANGED_FROM_INPUT=(\d+) ALPHA_CHANGED=(\d+) RGB_SUM=(\d+)",
            process.stdout)
        if match:
            changed, from_input, alpha, total = map(int, match.groups())
            # At the neutral control setting the complete source must pass
            # through unchanged, while the active setting must visibly react.
            ok = changed > 20 and alpha == 0 and total > 0 and from_input == 0
            print(name, "PASS" if ok else "FAIL_PIXELS", "changed", changed,
                "from_input", from_input, "alpha", alpha, "sum", total, flush=True)
            if not ok: failures.append((name, "did not alter pixels or alpha changed"))
        else:
            error = (process.stderr + "\n" + process.stdout).splitlines()
            print(name, "FAIL_COMPILE_OR_READBACK", " | ".join(error[-12:])[:1200], flush=True)
            failures.append((name, "\n".join(error[-12:])))
    print(f"MPV_ANIME_REAL_GPU_PASS={int(not failures)} COUNT={len(cases)} FAILED={len(failures)}")
    for name, error in failures: print("FAIL", name, error)
    if failures: sys.exit(1)
