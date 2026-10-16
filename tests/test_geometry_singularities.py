"""Source-contract regression for zero-radius geometry, plus real GPU suite.

The shader math is evaluated on the GPU by verify_noisemaker_ports.py;
these tests lock the signed nonzero denominator at its only division sites.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
PORTS = ROOT / 'data/examples/noisemaker-ports'


class GeometrySingularityTests(unittest.TestCase):
    def test_vortex_guards_squared_radius_without_erasing_its_sign(self):
        shader = (PORTS / 'nm_polar.shader').read_text()
        self.assertRegex(shader, r'float safeR2\s*=\s*\(r2\s*<\s*0\.0\s*\?\s*-1\.0\s*:\s*1\.0\)\s*\*\s*max\(abs\(r2\),\s*0\.0001\)\s*;')
        self.assertIn('uv = uv / safeR2;', shader)
        self.assertNotIn('uv = uv / r2;', shader)

    def test_tunnel_guards_radius_without_erasing_its_sign(self):
        shader = (PORTS / 'nm_tunnel.shader').read_text()
        self.assertRegex(shader, r'float safeR\s*=\s*\(r\s*<\s*0\.0\s*\?\s*-1\.0\s*:\s*1\.0\)\s*\*\s*max\(abs\(r\),\s*0\.0001\)\s*;')
        self.assertIn('0.3 / safeR + elapsed_time * speed', shader)
        self.assertNotIn('0.3 / r + elapsed_time * speed', shader)


if __name__ == '__main__':
    unittest.main()
