"""Prevent upstream examples and our fork-authored files from mixing again.

Provenance uses a checked-in snapshot so CI works without an upstream remote.
When synchronizing from upstream, update the snapshot deliberately.
"""
from pathlib import Path
import re
import unittest

REPO = Path(__file__).resolve().parents[1]
EXAMPLES = REPO / 'data/examples'
SNAPSHOT = REPO / 'tests/fixtures/upstream-example-paths.txt'


class ExampleLayoutTests(unittest.TestCase):
    def test_upstream_examples_keep_canonical_paths(self):
        expected = {line.strip() for line in SNAPSHOT.read_text().splitlines()
                    if line.strip() and not line.startswith('#')}
        actual = {p.name for p in EXAMPLES.iterdir() if p.is_file() and p.name != 'README.md'}
        self.assertEqual(expected, actual,
                         'upstream paths must remain intact; fork additions belong in examples/fork/')

    def test_fork_effects_live_under_named_fork_directory(self):
        fork = EXAMPLES / 'fork'
        self.assertTrue(fork.is_dir())
        expected = ['bloom-karis.shader', 'mixwell-fluid-glass.shader',
                    'orphic_chladni.shader', 'noisemaker-ports/nm_polar.shader',
                    'printmaking/ink_hatching.shader',
                    'mpv-anime-ports/anime_bilateral_mean.shader',
                    'potatofx-ports/palette_harmony.shader']
        for path in expected:
            with self.subTest(path=path):
                self.assertTrue((fork / path).is_file(), path)

    def test_all_shader_includes_still_resolve_after_move(self):
        for shader in EXAMPLES.rglob('*.shader'):
            for name in re.findall(r'^\s*#include\s+"([^"]+)"', shader.read_text(), re.M):
                with self.subTest(shader=str(shader.relative_to(EXAMPLES)), include=name):
                    self.assertTrue((shader.parent / name).is_file(), f'{shader}: {name}')

    def test_installer_still_bundles_all_examples_recursively(self):
        cmake = (REPO / 'CMakeLists.txt').read_text()
        self.assertIn('install(DIRECTORY data/examples ', cmake)
        self.assertIn('copy_directory ${CMAKE_CURRENT_SOURCE_DIR}/data', cmake)


if __name__ == '__main__':
    unittest.main()
