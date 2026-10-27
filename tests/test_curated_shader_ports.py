"""Contracts for curated Shaderfilter adaptations from real-world-shader,
HyperShaderFX, and SZION. Native compilation and pixel tests run separately.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "data/examples/myrqyry"

EXPECTED = {
    "rw_radial_fold.shader": ("Radial", "jankohlbach"),
    "rw_micro_noise_displace.shader": ("Noise", "jankohlbach"),
    "rw_organic_melt.shader": ("Melt", "jankohlbach"),
    "hf_focus_noise.shader": ("Noise", "HyperShaderFX"),
    "hf_focus_bulge.shader": ("Bulge", "HyperShaderFX"),
    "hf_interactive_rgb_shift.shader": ("RGB", "HyperShaderFX"),
    "hf_optical_halation.shader": ("Halation", "HyperShaderFX"),
    "sz_liquid_warp.shader": ("Liquid", "SZION"),
    "sz_chroma_mosh.shader": ("Chroma", "SZION"),
}

# A slider belongs to the transformation it controls, not global output opacity.
# These controls are expected to make their own effect neutral at zero.
NEUTRAL_CONTROL = {
    "rw_radial_fold.shader": "Fold_Strength",
    "rw_micro_noise_displace.shader": "Distortion",
    "rw_organic_melt.shader": "Displacement",
    "hf_focus_noise.shader": "Noise_Strength",
    "hf_focus_bulge.shader": "Strength",
    "hf_interactive_rgb_shift.shader": "Shift",
    "hf_optical_halation.shader": "Intensity",
    "sz_liquid_warp.shader": "Amount",
    "sz_chroma_mosh.shader": "Color_Mix",
}

class CuratedPorts(unittest.TestCase):
    def test_shaders_have_explicit_shaderfilter_contract(self):
        for file, (name, origin) in EXPECTED.items():
            with self.subTest(shader=file):
                text = (BASE / file).read_text()
                self.assertIn(name, text)
                self.assertIn(origin, text)
                self.assertIn("float4 mainImage(VertData v_in) : TARGET", text)
                self.assertIn("image.Sample(textureSampler,", text)
                self.assertNotIn("uniform float Mix<", text)
                self.assertNotIn("Effect Mix", text)
                self.assertNotIn("if (Mix <=", text)
                self.assertIn(f"uniform float {NEUTRAL_CONTROL[file]}<", text)
                self.assertIn("original.a", text)
                self.assertNotRegex(text, r"\b(uniform sampler2D|uniform texture2d image|technique Draw|#version)\b")
                self.assertNotIn("return lerp(original,", text)

    def test_documented_controls_are_semantic_not_global_opacity(self):
        catalog = (BASE / "CURATED-PORTS.md").read_text()
        self.assertNotIn(chr(96) + "Mix" + chr(96) + " bypass", catalog)
        self.assertNotIn(chr(96) + "Mix" + chr(96) + " control", catalog)
        for filename, param in NEUTRAL_CONTROL.items():
            self.assertIn(chr(96) + filename + chr(96), catalog)
            self.assertIn(chr(96) + param + " = 0" + chr(96), catalog)

    def test_attribution_notice_and_catalog(self):
        readme = (BASE / "CURATED-PORTS.md").read_text()
        for file in EXPECTED:
            with self.subTest(shader=file):
                self.assertIn(file, readme)
        for name in ("REAL-WORLD-SHADER-LICENSE.txt",):
            notice = (BASE / name).read_text()
            self.assertIn("Copyright (c) 2026 Jan Kohlbach", notice)
            self.assertIn("Permission is hereby granted", notice)

if __name__ == "__main__":
    unittest.main()
