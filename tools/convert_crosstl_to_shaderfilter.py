#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.10"
# dependencies = ["crosstl==3.4.0"]
# ///
"""Build-time CrossTL HLSL -> OBS Shaderfilter *profile* adapter.

Currently supports exactly the normalized Glyphfield Soft Register material.
Fail closed on unknown translation shapes. This is NOT an automatic arbitrary
GLSL, ReShade FX, WGSL, multipass or OBS .effect compiler.
"""
from __future__ import annotations

import argparse
import hashlib
import re
from pathlib import Path
import crosstl

PROFILE = "glyphfield-soft-register"

SCALARS: tuple[tuple[str, str, str, str, str, str], ...] = (
    ("u_strength", "Warp", "0.75", "0.0", "2.0", "0.05"),
    ("u_detail", "Detail", "3.0", "1.0", "6.0", "0.1"),
    ("u_frequency", "Frequency", "1.8", "0.5", "6.0", "0.1"),
    ("u_grain", "Grain", "5.0", "0.0", "50.0", "1.0"),
    ("u_amplitude", "Registration", "1.0", "0.0", "4.0", "0.1"),
    ("u_density", "Dot Density", "1.0", "0.2", "2.0", "0.05"),
    ("u_brightness", "Brightness", "1.0", "0.2", "2.0", "0.05"),
    ("u_rotation", "Rotation", "0.0", "-180.0", "180.0", "1.0"),
    ("u_scale", "Scale", "1.0", "0.25", "3.0", "0.05"),
)


def replace_expected(source: str, old: str, new: str, count: int = 1) -> str:
    observed = source.count(old)
    if observed != count:
        raise ValueError(f"CrossTL output changed: expected {count} occurrence(s) of {old[:90]!r}, found {observed}")
    return source.replace(old, new)


def compile_profile(glsl: Path) -> str:
    source = glsl.read_text(encoding="utf-8")
    # Reject unrelated fragments rather than applying guessed shader rewrites.
    required = (
        "#version 300 es", "float screenDots(", "vec2 studioUv(",
        "vec3 oklabToLinear(", "u_lab_a", "u_lab_b", "u_lab_c",
        "fragColor = writeColorWithGrain(", "vec3 hash33(vec3 p3Initial)",
    )
    if any(x not in source for x in required):
        raise ValueError("Only the normalized Glyphfield Soft Register GLSL source is supported")
    text = crosstl.translate(str(glsl), backend="hlsl", format_output=False)
    start = "cbuffer Uniforms : register(b0) {"
    if text.count(start) != 1:
        raise ValueError("Expected exactly one CrossTL HLSL uniform buffer")
    left = text.index(start)
    right = text.index("};", left) + 2
    block = text[left:right]
    expected = {
        "u_resolution", "u_pointer", "u_time",
        "u_color_a", "u_color_b", "u_color_c",
        "u_lab_a", "u_lab_b", "u_lab_c",
        "u_strength", "u_detail", "u_frequency", "u_grain",
        "u_amplitude", "u_density", "u_brightness", "u_rotation", "u_scale",
    }
    names = set(re.findall(r"\b(?:float|float2|float3|float4|int)\s+(u_\w+)\s*;", block))
    if names != expected:
        raise ValueError(f"Unknown/unbound uniform ABI: {sorted(names ^ expected)}")
    # OBS Shaderfilter supplies real source dimensions/time. Palette OKLab values
    # are intentionally fixed for this first profile, not misrepresented as RGB UI.
    bindings = """// OBS Shaderfilter template supplies these host uniforms.
#define u_resolution uv_size
#define u_time elapsed_time
#define u_pointer float2(0.5, 0.5)
#define u_lab_a float3(0.42, 0.07, -0.04)
#define u_lab_b float3(0.65, 0.10, 0.08)
#define u_lab_c float3(0.92, -0.02, 0.06)
"""
    for key, label, default, minimum, maximum, step in SCALARS:
        bindings += (
            f'uniform float {key}<\n'
            f'    string label = "{label}";\n'
            '    string widget_type = "slider";\n'
            f'    float minimum = {minimum}; float maximum = {maximum}; float step = {step};\n'
            f'> = {default};\n'
        )
    text = text[:left] + bindings + "\n" + text[right:]
    for name in ("PI", "TAU", "REFERENCE_HEIGHT"):
        pattern = rf"^static const float {name} = ([0-9.]+);$"
        text, count = re.subn(pattern, rf"#define {name} \1", text, flags=re.M)
        if count != 1:
            raise ValueError(f"Expected the CrossTL {name} constant")
    text = replace_expected(text,
        "static const float2x2 OCTAVE = transpose(float2x2(1.6, 1.2, -1.2, 1.6));", "")
    # CrossTL currently emits a bitcast idiom for unary minus in HLSL;
    # OBS's GLSL backend does not implement asuint/asfloat.
    text = replace_expected(text,
        "asfloat(asuint(sin(angle)) ^ 0x80000000u)", "-sin(angle)", 2)
    text = replace_expected(text,
        "asfloat(asuint((peak - 0.82)) ^ 0x80000000u)", "(-(peak - 0.82))")
    # OBS's effect HLSL frontend does not support dynamically constructed
    # float2x2 (and some backends reject overloaded function names).
    text = replace_expected(text, "OCTAVE * p",
        "float2(1.6 * p.x - 1.2 * p.y, 1.2 * p.x + 1.6 * p.y)", 2)
    for vector in ("p", "reference"):
        text = replace_expected(text,
            f"mul(transpose(float2x2(cos(angle), -sin(angle), sin(angle), cos(angle))), {vector})",
            f"float2(cos(angle)*{vector}.x + sin(angle)*{vector}.y, -sin(angle)*{vector}.x + cos(angle)*{vector}.y)")
    # Function prototypes are legal HLSL, but the libobs effect parser treats
    # them as definitions and emits Expected '{'. The definitions remain.
    prototype = r"^(?:float(?:[234](?:x[234])?)?|int(?:[234])?)\s+[A-Za-z_]\w*\([^;\n]*\);\s*$"
    text, removed = re.subn(prototype, "", text, flags=re.M)
    if removed < 20:
        raise ValueError("CrossTL output lacks expected function prototypes")
    text = replace_expected(text, "float gnoise(float2 p)", "float gnoise2(float2 p)")
    text = replace_expected(text, "float gnoise(float3 p)", "float gnoise3(float3 p)")
    text = replace_expected(text, "float fbm(float2 pInitial, int octaves)",
        "float fbm2(float2 pInitial, int octaves)")
    text = replace_expected(text, "float fbm(float3 pInitial, int octaves)",
        "float fbm3(float3 pInitial, int octaves)")
    # Two sites in order: 2D and 3D. Reject reordering rather than assuming.
    first = text.index("float fbm2(")
    second = text.index("float fbm3(")
    warp = text.index("float2 warp(", second)
    section2 = text[first:second]
    section3 = text[second:warp]
    if section2.count("gnoise(p)") != 1 or section3.count("gnoise(p)") != 1:
        raise ValueError("CrossTL's fbm overload sites changed")
    text = text[:first] + section2.replace("gnoise(p)", "gnoise2(p)") + section3.replace("gnoise(p)", "gnoise3(p)") + text[warp:]
    text = replace_expected(text, "fbm(float3(", "fbm3(float3(", 2)
    text = replace_expected(text,
        "float4 PSMain(float4 _crossglFragCoord : SV_Position): SV_Target0 {",
        "float4 mainImage(VertData v_in) : TARGET {\n"
        "    float4 _crossglFragCoord = float4(v_in.uv * uv_size, 0.0, 1.0);")
    forbidden = ("cbuffer", "register(b", "SV_Position", "SV_Target",
                 "asfloat(", "asuint(", "float2x2(", "OCTAVE", "gnoise(",
                 "fbm(", "PSMain(", "texture2D(", "Texture2D", "SamplerState")
    for term in forbidden:
        if term in text:
            raise ValueError(f"Unsupported translation output left behind: {term}")
    digest = hashlib.sha256(source.encode()).hexdigest()[:16]
    return (
        "// Generated by CrossTL 3.4.0 + verified OBS Shaderfilter profile; do not hand-edit.\n"
        f"// Source: Glyphfield Soft Register normalized GLSL; SHA-256 prefix {digest}\n"
        "// Kevin Liu (c) 2026, MIT license; see docs/CROSSTL_OBS_BRIDGE.md\n"
        "// Standalone procedural source: overrides input pixels, outputs opaque RGBA.\n"
        + text.rstrip() + "\n"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", choices=[PROFILE], required=True)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    material = compile_profile(args.input)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(material, encoding="utf-8")
    print(f"CROSSTL_OBS_PROFILE_GENERATED={args.profile} bytes={len(material)}")


if __name__ == "__main__":
    main()
