"""Check complete localization coverage and packaged language resources.

Set KIPIR_BUILT_APP to a built Kipir.app to check its packaged resources (default: the documented build path).
"""
from pathlib import Path
import os
import plistlib
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
# Keys assembled at runtime from enum raw values; their completeness is checked explicitly below.
DYNAMIC_PREFIXES = ('status.', 'ui.status.note.', 'ui.notif.state.', 'exercise.')


def table(language):
    source = (ROOT / f'Kipir/Resources/{language}.lproj/Localizable.strings').read_text()
    entries = re.findall(r'^"([^"]+)" = "(.+)";$', source, re.M)
    return entries


def swift_sources():
    return [p.read_text() for p in (ROOT / 'Kipir').rglob('*.swift')]


def enum_cases(path, name):
    source = (ROOT / path).read_text()
    start = source.index('{', re.search(r'enum %s\b' % name, source).end())
    depth, top = 0, []
    for char in source[start:]:
        depth += char == '{'
        depth -= char == '}'
        if depth == 0:
            break
        top.append(char if depth == 1 else ' ')  # keep only the enum's own level
    body = ''.join(top)
    return [c for line in re.findall(r'\bcase ([^\n{}]+)', body)
            for c in (part.strip() for part in line.split(',')) if re.fullmatch(r'[A-Za-z]+', c)]


class LocalizationTests(unittest.TestCase):
    def setUp(self):
        self.tables = {}
        for language in ('tr', 'en'):
            entries = table(language)
            self.assertEqual(len(entries), len(set(key for key, _ in entries)), f'duplicate key in {language}')
            self.tables[language] = dict(entries)

    def test_complete_languages(self):
        self.assertEqual(self.tables['tr'].keys(), self.tables['en'].keys())
        keys = set(self.tables['tr'])
        for source in swift_sources():
            for key in re.findall(r'L\("([^"\\]+)"\)', source):
                self.assertIn(key, keys)
        self.assertEqual(self.tables['en']['setting.language'], 'Language')
        self.assertEqual(self.tables['tr']['setting.language'], 'Dil')

    def test_format_arguments_match(self):
        for key, tr in self.tables['tr'].items():
            en = self.tables['en'][key]
            self.assertEqual(re.findall(r'%[@d]', tr), re.findall(r'%[@d]', en), key)

    def test_dynamic_keys_exist(self):
        keys = set(self.tables['tr'])
        for status in enum_cases('Kipir/Core/Settings.swift', 'WorkStatus'):
            self.assertIn(f'status.{status}', keys)
            if status != 'working':
                self.assertIn(f'ui.status.note.{status}', keys)
        for state in enum_cases('Kipir/Core/QualityOfLife.swift', 'NotificationEffectiveState'):
            self.assertIn(f'ui.notif.state.{state}', keys)
        for movement in enum_cases('Kipir/Core/Exercises.swift', 'Movement'):
            self.assertIn(f'exercise.{movement}', keys)
            self.assertIn(f'exercise.{movement}.instruction', keys)

    def test_no_unused_keys(self):
        literals = set()
        for source in swift_sources():
            literals.update(re.findall(r'"([A-Za-z][A-Za-z0-9_.]*)"', source))
        unused = [k for k in self.tables['tr'] if k not in literals and not k.startswith(DYNAMIC_PREFIXES)]
        self.assertEqual(unused, [])

    def test_bundle_declares_both_localizations(self):
        info = (ROOT / 'Kipir/Info.plist').read_text()
        self.assertRegex(info, r'<key>CFBundleLocalizations</key><array><string>tr</string><string>en</string></array>')

    def test_built_resources(self):
        app = Path(os.environ.get('KIPIR_BUILT_APP', ROOT / 'build/Build/Products/Debug/Kipir.app'))
        for language in ('tr', 'en'):
            path = app / f'Contents/Resources/{language}.lproj/Localizable.strings'
            self.assertTrue(path.is_file(), str(path))
        with open(app / 'Contents/Info.plist', 'rb') as f:
            self.assertEqual(plistlib.load(f)['CFBundleLocalizations'], ['tr', 'en'])


if __name__ == '__main__':
    unittest.main()
