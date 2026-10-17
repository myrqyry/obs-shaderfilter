"""Targeted regression contracts from the PR #11 code review.

These source-level invariants complement real libobs GPU pixel tests from
verify_potatofx_palette.py; no mocked rendering is used as success evidence.
"""
import re
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
SHADER=(ROOT/'data/examples/potatofx-ports/palette_harmony.shader').read_text()
HELPER=(ROOT/'data/stdlib/oklab.glsl').read_text()

class PaletteReviewRegression(unittest.TestCase):
    def test_palette_level_count_uses_exact_requested_bins(self):
        self.assertIn('float bins = float(levels - 1);',SHADER)
        self.assertIn('floor(lightness * bins + 0.5) / bins',SHADER)
        self.assertNotIn('ceil(lightness * float(levels))',SHADER)

    def test_picker_has_only_rgb_controls(self):
        self.assertRegex(SHADER,r'uniform\s+float3\s+base_color\s*<')
        self.assertNotRegex(SHADER,r'uniform\s+float4\s+base_color\s*<')
        self.assertIn('obs_properties_add_color(group, param_name, display_name.array)',
                      (ROOT/'obs-shaderfilter.c').read_text())

    def test_grayscale_hue_is_defined(self):
        self.assertIn('float chroma = length(c.yz);',HELPER)
        self.assertRegex(HELPER,r'if\s*\(chroma\s*<=\s*1\.0e-6\)\s*return\s+float3\(c.x,\s*0\.0,\s*0\.0\)')
        self.assertNotIn('length(c.yz), atan(c.z, c.y)',HELPER)

    def test_triad_is_bounded_to_three_true_hue_families(self):
        self.assertIn('int triadIndex = min(2, int(floor(triadProgress * 3.0)));',SHADER)
        self.assertIn('float(triadIndex) * 2.0943951023931953',SHADER)
        self.assertNotIn('floor(lightness * 3.0 / control)',SHADER)

if __name__=='__main__':
    unittest.main()
