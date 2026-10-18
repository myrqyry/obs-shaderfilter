"""Regression: `install-user` migrates only known legacy example files safely."""
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
SCRIPT=ROOT/'cmake/MigrateLegacyExamples.cmake'
MANIFEST=ROOT/'cmake/legacy-example-paths.txt'

class MigratedUserInstall(unittest.TestCase):
    def test_manifest_matches_original_moved_paths(self):
        # Use only committed files: GitHub CI may have no historical local
        # ref for the original fork branch used to derive this manifest.
        entries=[s for s in MANIFEST.read_text().splitlines()
                 if s and not s.startswith('#')]
        manifest=set(entries)
        self.assertEqual(len(entries),78)
        self.assertEqual(len(manifest),78)
        for rel in manifest:
            self.assertFalse((ROOT/'data/examples'/rel).exists(),rel)
            self.assertTrue((ROOT/'data/examples/myrqyry'/rel).is_file(),rel)

    def test_migrates_only_known_files_and_preserves_custom_neighbors(self):
        self.assertTrue(SCRIPT.exists(),'installer migration script missing')
        with tempfile.TemporaryDirectory() as tmp:
            data=Path(tmp)/'plugin data';examples=data/'examples'
            old=examples/'noisemaker-ports/nm_channel.shader'
            old.parent.mkdir(parents=True)
            old.write_bytes(b'user edited legacy contents')
            other=old.parent/'my-own-look.shader'
            other.write_bytes(b'custom shader')
            root=examples/'bloom-karis.shader';root.write_bytes(b'legacy-root-shader')
            unlisted=examples/'local_custom.shader';unlisted.write_bytes(b'solo custom')
            new=examples/'myrqyry/noisemaker-ports/nm_channel.shader'
            new.parent.mkdir(parents=True);new.write_bytes(b'current new shader')
            def migrate():
                return subprocess.run(['cmake',f'-DPLUGIN_DATA_DIR={data}',
                                       '-P',str(SCRIPT)],text=True,capture_output=True)
            result=migrate()
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertFalse(old.exists());self.assertFalse(root.exists())
            self.assertEqual(other.read_bytes(),b'custom shader')
            self.assertEqual(unlisted.read_bytes(),b'solo custom')
            self.assertEqual(new.read_bytes(),b'current new shader')
            backup=data/'legacy-shaderfilter-examples-backup'
            self.assertEqual((backup/'noisemaker-ports/nm_channel.shader').read_bytes(),b'user edited legacy contents')
            self.assertEqual((backup/'bloom-karis.shader').read_bytes(),b'legacy-root-shader')
            self.assertEqual(migrate().returncode,0)

    def test_fails_before_modifying_any_file_if_backup_would_collide(self):
        with tempfile.TemporaryDirectory() as tmp:
            data=Path(tmp)/'data';e=data/'examples';e.mkdir(parents=True)
            first=e/'bloom-karis.shader';first.write_bytes(b'legacy')
            other=e/'mixwell-fluid-glass.shader';other.write_bytes(b'more legacy')
            preserved=data/'legacy-shaderfilter-examples-backup/bloom-karis.shader'
            preserved.parent.mkdir(parents=True);preserved.write_bytes(b'earlier copy')
            result=subprocess.run(['cmake',f'-DPLUGIN_DATA_DIR={data}',
                                   '-P',str(SCRIPT)],capture_output=True,text=True)
            self.assertNotEqual(result.returncode,0)
            self.assertEqual(first.read_bytes(),b'legacy')
            self.assertEqual(other.read_bytes(),b'more legacy')
            self.assertEqual(preserved.read_bytes(),b'earlier copy')

if __name__=='__main__':unittest.main()
