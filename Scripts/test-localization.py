"""Check complete localization coverage and packaged language resources."""
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]

class LocalizationTests(unittest.TestCase):
    def test_complete_languages(self):
        tables = []
        for language in ('tr', 'en'):
            source = (ROOT / f'Kipir/Resources/{language}.lproj/Localizable.strings').read_text()
            entries = re.findall(r'^"([^"]+)" = "(.+)";$', source, re.M)
            self.assertEqual(len(entries), len(set(key for key, _ in entries)))
            tables.append(dict(entries))
        self.assertEqual(tables[0].keys(), tables[1].keys())
        keys = set(tables[0])
        for source in (ROOT / 'Kipir').rglob('*.swift'):
            for key in re.findall(r'L\("([^"\\]+)"\)', source.read_text()):
                self.assertIn(key, keys)
        self.assertEqual(tables[1]['setting.language'], 'Language')
        self.assertEqual(tables[0]['setting.language'], 'Dil')

    def test_built_resources(self):
        for language in ('tr', 'en'):
            path = ROOT / f'build/Build/Products/Debug/Kipir.app/Contents/Resources/{language}.lproj/Localizable.strings'
            self.assertTrue(path.is_file(), str(path))

if __name__ == '__main__':
    unittest.main()
