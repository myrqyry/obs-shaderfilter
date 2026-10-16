"""Regression contracts for disabled MPV port filters (GPU output separately tested)."""
from pathlib import Path
import unittest

SHADERS = Path(__file__).resolve().parents[1] / 'data/examples/mpv-anime-ports'


class MpvDisabledFilterTests(unittest.TestCase):
    def test_bilateral_zero_mix_returns_before_the_25_tap_kernel(self):
        shader = (SHADERS / 'anime_bilateral_mean.shader').read_text()
        self.assertIn('if (blend_factor <= 0.0) return center;', shader)
        self.assertLess(shader.index('if (blend_factor <= 0.0) return center;'),
                        shader.index('for (int y=-2; y<=2; y++)'))

    def test_cas_zero_mix_returns_before_neighborhood_sampling(self):
        shader = (SHADERS / 'cas_luma_sharpen.shader').read_text()
        self.assertIn('if (amount <= 0.0) return center;', shader)
        self.assertLess(shader.index('if (amount <= 0.0) return center;'),
                        shader.index('float a = mpvLuma('))

    def test_only_used_luma_helpers_are_kept(self):
        for name in ('anime_bilateral_mean', 'static_chroma_grain', 'static_luma_grain'):
            with self.subTest(shader=name):
                self.assertNotIn('float mpvLuma(', (SHADERS / f'{name}.shader').read_text())


if __name__ == '__main__':
    unittest.main()
