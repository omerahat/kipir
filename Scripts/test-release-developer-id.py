"""Developer ID script guards; run with python3 Scripts/test-release-developer-id.py.

Everything runs with a scrubbed environment and PATH stubs for `security` and
`xcodebuild`. No real build, signing, keychain access or notarytool call happens.
"""
import os
import pathlib
import shutil
import stat
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).with_name("release-developer-id.sh")
PACKAGE = pathlib.Path(__file__).with_name("package-release.sh")
FAKE_IDENTITY = "Developer ID Application: Fake Person (ABCDE12345)"


def stub(directory, name, body):
    path = directory / name
    path.write_text("#!/bin/bash\n" + body)
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


class Sandbox:
    def __enter__(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temporary.name)
        (self.root / "Scripts").mkdir()
        self.script = self.root / "Scripts/release-developer-id.sh"
        shutil.copyfile(SCRIPT, self.script)
        (self.root / "Config.xcconfig").write_text("MARKETING_VERSION = 9.9.9\n")
        self.bin = self.root / "stubs"
        self.bin.mkdir()
        self.calls = self.root / "calls.txt"
        stub(self.bin, "security", 'echo "security $*" >> "%s"\necho "$STUB_IDENTITIES"\n' % self.calls)
        stub(self.bin, "xcodebuild", 'echo "xcodebuild $*" >> "%s"\nexit 1\n' % self.calls)
        stub(self.bin, "xcrun", 'echo "xcrun $*" >> "%s"\nexit 1\n' % self.calls)
        return self

    def __exit__(self, *exc):
        self.temporary.cleanup()

    def run(self, *args, **env):
        scrubbed = {"PATH": "%s:/usr/bin:/bin" % self.bin, "HOME": str(self.root)}
        scrubbed.update(env)
        return subprocess.run(["bash", str(self.script), *args], capture_output=True, env=scrubbed, text=True)

    def calls_text(self):
        return self.calls.read_text() if self.calls.exists() else ""


class DeveloperIdGuards(unittest.TestCase):
    def test_syntax(self):
        for script in (SCRIPT, PACKAGE):
            self.assertEqual(subprocess.run(["bash", "-n", str(script)]).returncode, 0, script)

    def test_blocked_without_environment(self):
        with Sandbox() as box:
            result = box.run()
            self.assertEqual(result.returncode, 2)
            self.assertIn("BLOCKED:", result.stderr)
            for name in ("KIPIR_DEVELOPER_ID", "KIPIR_NOTARY_PROFILE", "store-credentials"):
                self.assertIn(name, result.stderr)
            self.assertEqual(box.calls_text(), "")
            self.assertFalse((box.root / "build").exists())

    def test_blocked_with_only_one_variable(self):
        with Sandbox() as box:
            for env in ({"KIPIR_DEVELOPER_ID": FAKE_IDENTITY}, {"KIPIR_NOTARY_PROFILE": "profile"}):
                result = box.run(**env)
                self.assertEqual(result.returncode, 2)
                self.assertIn("BLOCKED:", result.stderr)
            self.assertEqual(box.calls_text(), "")

    def test_rejects_non_developer_id_identity_and_unknown_arguments(self):
        with Sandbox() as box:
            result = box.run(KIPIR_DEVELOPER_ID="Apple Development: Someone (ABCDE12345)", KIPIR_NOTARY_PROFILE="p")
            self.assertEqual(result.returncode, 2)
            self.assertIn("Developer ID Application", result.stderr)
            for args in (("--bogus",), ("--notarize", "extra")):
                result = box.run(*args)
                self.assertEqual(result.returncode, 1)
                self.assertIn("Usage:", result.stderr)
            self.assertEqual(box.calls_text(), "")

    def test_missing_identity_fails_before_build(self):
        with Sandbox() as box:
            result = box.run(
                KIPIR_DEVELOPER_ID=FAKE_IDENTITY, KIPIR_NOTARY_PROFILE="p", STUB_IDENTITIES="  0 valid identities found"
            )
            self.assertEqual(result.returncode, 2)
            self.assertIn("identity not found", result.stderr)
            calls = box.calls_text()
            self.assertIn("security find-identity -v -p codesigning", calls)
            self.assertNotIn("xcodebuild", calls)
            self.assertNotIn("xcrun", calls)
            self.assertFalse((box.root / "build").exists())

    def test_existing_artifacts_are_never_overwritten(self):
        for name in ("Kipir-9.9.9.zip", "Kipir-9.9.9-unnotarized.zip", "Kipir-9.9.9.zip.sha256"):
            with Sandbox() as box:
                (box.root / "dist").mkdir()
                artifact = box.root / "dist" / name
                artifact.write_bytes(b"existing release")
                result = box.run(KIPIR_DEVELOPER_ID=FAKE_IDENTITY, KIPIR_NOTARY_PROFILE="p")
                self.assertEqual(result.returncode, 1)
                self.assertIn("Refusing to overwrite", result.stderr)
                self.assertEqual(artifact.read_bytes(), b"existing release")
                self.assertEqual(box.calls_text(), "")

    def test_invalid_version_fails_before_identity_lookup(self):
        with Sandbox() as box:
            (box.root / "Config.xcconfig").write_text("MARKETING_VERSION = invalid\n")
            result = box.run(KIPIR_DEVELOPER_ID=FAKE_IDENTITY, KIPIR_NOTARY_PROFILE="p")
            self.assertEqual(result.returncode, 1)
            self.assertIn("three-part", result.stderr)
            self.assertEqual(box.calls_text(), "")

    def test_build_receives_developer_id_overrides_only(self):
        with Sandbox() as box:
            result = box.run(
                KIPIR_DEVELOPER_ID=FAKE_IDENTITY,
                KIPIR_NOTARY_PROFILE="p",
                STUB_IDENTITIES='  1) 0123456789ABCDEF "%s"\n     1 valid identities found' % FAKE_IDENTITY,
            )
            self.assertEqual(result.returncode, 1)  # stub xcodebuild fails on purpose
            self.assertIn("Build failed", result.stderr)
            build = [line for line in box.calls_text().splitlines() if line.startswith("xcodebuild")]
            self.assertEqual(len(build), 1)
            for flag in (
                "CODE_SIGN_IDENTITY=" + FAKE_IDENTITY,
                "CODE_SIGN_STYLE=Manual",
                "OTHER_CODE_SIGN_FLAGS=--timestamp",
                "ENABLE_HARDENED_RUNTIME=YES",
                "-configuration Release",
            ):
                self.assertIn(flag, build[0])
            self.assertNotIn("xcrun", box.calls_text())  # no notarytool in non-notarize mode

    def test_notarytool_only_reachable_after_notarize_branch(self):
        lines = SCRIPT.read_text().splitlines()
        branch = next(i for i, line in enumerate(lines) if "$notarize" in line and "== 0" in line)
        exit_after = next(i for i, line in enumerate(lines) if i > branch and line.strip() == "exit 0")
        commands = [(i, line) for i, line in enumerate(lines) if line.lstrip().startswith("xcrun notarytool")]
        self.assertTrue(commands)  # executed commands only, not the BLOCKED help text
        for index, line in commands:
            self.assertGreater(index, exit_after, line)

    def test_no_quarantine_or_gatekeeper_weakening(self):
        for script in (SCRIPT, PACKAGE):
            text = script.read_text()
            for forbidden in ("xattr", "spctl --master-disable", "--global-disable"):
                self.assertNotIn(forbidden, text)

    def test_package_release_writes_tracked_cask_only_on_request(self):
        lines = PACKAGE.read_text().splitlines()
        writes = [(i, line) for i, line in enumerate(lines) if "Casks/kipir.rb" in line and not line.lstrip().startswith(("#", "printf"))]
        self.assertTrue(writes)
        guard = next(i for i, line in enumerate(lines) if 'WRITE_CASK:-}" == "1"' in line)
        for index, line in writes:
            self.assertGreater(index, guard, line)
        self.assertIn("cask_file=dist/kipir.rb", lines)


if __name__ == "__main__":
    unittest.main()
