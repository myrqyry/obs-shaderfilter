#!/usr/bin/env python3
"""Compile the Mixwell source shader with its real Shaderfilter C templates.

Runs on an OBS/libobs-capable machine without touching OBS configuration.
"""
from __future__ import annotations

import shlex
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHADER = ROOT / "data/examples/mixwell-fluid-glass.shader"
SOURCE = ROOT / "obs-shaderfilter.c"
LICENSE = ROOT / "docs/shaders/mixwell-fluid-glass/LICENSE-MIXWELL-MIT.txt"
NATIVE = ROOT / "tests/obs_native_shader_compile.c"


def check_contract(shader: str) -> None:
    # Ignore comments and allow harmless whitespace changes around the sampler.
    executable = re.sub(r"/\*.*?\*/|//[^\n]*", "", shader, flags=re.S)
    assert len(re.findall(r"\bimage\s*\.\s*Sample\s*\(\s*textureSampler\s*,", executable)) == 2
    assert "fluidGlassBrushVelocity" in shader
    assert "fluidGlassReverseBrush" in shader
    assert "for (int i = 0; i < 16; i++)" in shader
    assert "if (i >= FluidGlass_Quality) break;" in shader
    assert 'int option_0_value = 8;' in shader and 'int option_1_value = 16;' in shader
    assert 'int option_0_value = 1;' in shader and 'int option_1_value = 2;' in shader
    assert "if (strength <= 0.0)" in shader
    assert "elapsed_time * FluidGlass_Speed" in shader
    assert "float4 mainImage(VertData v_in) : TARGET" in shader
    assert "uniform texture2d image;" not in shader
    assert "technique Draw" not in shader
    assert not list((ROOT / "data/examples").glob("MIXWELL_FLUID_GLASS.*")), "Nonshader docs must not be in examples"
    assert not (ROOT / "data/examples/LICENSE-MIXWELL-MIT.txt").exists()
    license_text = LICENSE.read_text()
    assert "MIT License" in license_text
    assert "Copyright (c) 2026 Doug L. James and Ethan James" in license_text
    print("MIXWELL_STATIC_CONTRACT_PASS=1")


def decode_c_template(source: str, name: str) -> str:
    prefix = f'static const char *effect_template_{name} = "'
    assert source.count(prefix) == 1, "Shaderfilter template changed"
    original = source.split(prefix, 1)[1].split('";', 1)[0]
    return original.replace("\\\n", "").replace("\\n", "\n")


def main() -> None:
    text = SHADER.read_text()
    check_contract(text)
    source = SOURCE.read_text()
    begin = decode_c_template(source, "begin")
    end = decode_c_template(source, "end")
    # Shaderfilter strips the HLSL loop annotation for OpenGL.
    combined = "#define OPENGL 1\n" + begin + text.replace("[loop]", "") + "\n" + end
    assert combined.count("technique Draw") == 1
    assert combined.count("float4 mainImage(VertData v_in) : TARGET") == 1
    with tempfile.TemporaryDirectory(prefix="obs-mixwell-") as dirname:
        directory = Path(dirname)
        effect = directory / "fluid-glass.effect"
        binary = directory / "check-native-effect"
        effect.write_text(combined)
        flags = shlex.split(
            subprocess.check_output(["pkg-config", "--cflags", "--libs", "libobs"], text=True)
        )
        subprocess.run(["cc", "-O2", "-Wall", "-Wextra", str(NATIVE), "-o", str(binary), *flags],
                       check=True)
        completed = subprocess.run([str(binary), str(effect)], check=False,
                                   text=True, capture_output=True)
        if completed.returncode:
            raise RuntimeError(f"Native OBS shader compile failed ({completed.returncode}):\n"
                               + completed.stdout + "\n" + completed.stderr)
        assert "NATIVE_OBS_SHADER_COMPILE_PASS=1" in completed.stdout, completed.stdout
        assert "NATIVE_OBS_SHADER_RENDER_PASS=1" in completed.stdout, completed.stdout
        print(completed.stdout.strip())
        print("MIXWELL_NATIVE_OBS_PASS=1")


if __name__ == "__main__":
    main()
