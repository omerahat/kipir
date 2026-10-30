"""Packaging input guards; run with python3 Scripts/test-package-release.py."""
import pathlib
import shutil
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).with_name("package-release.sh")


class PackagingGuards(unittest.TestCase):
    def test_rejects_arguments(self):
        result = subprocess.run(["bash", str(SCRIPT), "1.2.3"], capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"Usage:", result.stderr)

    def test_invalid_version_and_existing_archive_fail_before_build(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            (root / "Scripts").mkdir()
            script = root / "Scripts/package-release.sh"
            shutil.copyfile(SCRIPT, script)
            config = root / "Config.xcconfig"
            config.write_text("MARKETING_VERSION = invalid\n")
            result = subprocess.run(["bash", str(script)], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(b"three-part", result.stderr)
            config.write_text("MARKETING_VERSION = 0.1.0\n")
            (root / "dist").mkdir()
            archive = root / "dist/Kipir-0.1.0.zip"
            archive.write_bytes(b"existing release")
            result = subprocess.run(["bash", str(script)], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(b"Refusing to overwrite", result.stderr)
            self.assertEqual(archive.read_bytes(), b"existing release")
            self.assertFalse((root / "Casks").exists())
            self.assertFalse((root / "build").exists())


if __name__ == "__main__":
    unittest.main()
