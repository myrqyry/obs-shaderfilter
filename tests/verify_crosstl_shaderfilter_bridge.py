#!/usr/bin/env python3
"""CrossTL -> Shaderfilter: checked-in reproduction plus real libobs/OpenGL pixels."""
from pathlib import Path
import subprocess
import tempfile
import re
import shlex

REPO = Path(__file__).resolve().parents[1]
FIXTURE = REPO / "tests/fixtures/glyphfieldSoftRegister.frag.glsl"
CONVERTER = REPO / "tools/convert_crosstl_to_shaderfilter.py"
OUTPUT = REPO / "data/examples/myrqyry/glyphfield-soft-register-procedural.shader"
NATIVE = REPO / "tests/native_shader_pixel_probe.cpp"
SOURCE = REPO / "obs-shaderfilter.c"

def template(name: str) -> str:
    raw = SOURCE.read_text()
    key = f'static const char *effect_template_{name} = "'
    assert raw.count(key) == 1, "Missing current native Shaderfilter template"
    return raw.split(key, 1)[1].split('";', 1)[0].replace("\\\n", "").replace("\\n", "\n")

def run() -> None:
    with tempfile.TemporaryDirectory(prefix="crosstl-obs-proof-") as folder:
        base = Path(folder)
        candidate = base / "material.shader"
        subprocess.run(["uv", "run", str(CONVERTER), "--profile", "glyphfield-soft-register",
                        "--input", str(FIXTURE), "--output", str(candidate)], check=True)
        actual = candidate.read_text()
        assert actual == OUTPUT.read_text(), "Generated source out of date"
        # Refuse an unrelated/changed material instead of claiming that the
        # CrossTL HLSL backend alone establishes Shaderfilter compatibility.
        invalid = base / "unsupported.frag.glsl"
        invalid.write_text(FIXTURE.read_text().replace(
            "vec3 hash33(vec3 p3Initial)", "vec3 removedHash(vec3 p3Initial)", 1
        ))
        reject_path = base / "should-not-exist.shader"
        rejected = subprocess.run(
            ["uv", "run", str(CONVERTER), "--profile", "glyphfield-soft-register",
             "--input", str(invalid), "--output", str(reject_path)],
            text=True, capture_output=True,
        )
        assert rejected.returncode != 0 and not reject_path.exists(), (
            "Unsupported foreign shader was accepted"
        )
        assert "float4 mainImage(VertData v_in) : TARGET" in actual
        assert "uniform float u_strength" in actual
        for forbidden in ("cbuffer Uniforms", "SV_Position", "SV_Target0",
                          "asfloat(", "asuint(", "float2x2("):
            assert forbidden not in actual, forbidden
        effect = base / "material.effect"
        effect.write_text("#define OPENGL 1\n" + template("begin") + actual + "\n" + template("end"))
        binary = base / "gpu-probe"
        includedir = subprocess.check_output(["pkg-config", "--variable=includedir", "libobs"], text=True).strip()
        libs = shlex.split(subprocess.check_output(["pkg-config", "--libs", "libobs"], text=True))
        subprocess.run(["g++", "-std=c++17", "-O2", "-I" + includedir + "/obs",
                        str(NATIVE), "-o", str(binary), *libs], check=True)
        run = subprocess.run(["xvfb-run", "-a", "-s", "-screen 0 1280x720x24",
                              str(binary), str(effect), "u_strength", "0.0", "1.2"],
                             text=True, capture_output=True, timeout=35)
        match = re.search(r"GPU_READBACK_PASS=1 CONTROL=u_strength CHANGED=(\d+) CHANGED_FROM_INPUT=(\d+) ALPHA_CHANGED=(\d+) RGB_SUM=(\d+)",run.stdout)
        assert run.returncode == 0 and match, (run.stdout + run.stderr)[-4500:]
        changed, diff_input, alpha, rgb = map(int, match.groups())
        assert changed > 500 and diff_input > 500 and rgb > 10000, (changed,diff_input,rgb)
        print(f"CROSSTL_OBS_NATIVE_GPU_PASS=1 pixels_changed={changed} rgb_sum={rgb}")
if __name__ == "__main__":
    run()
