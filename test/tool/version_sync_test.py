import tempfile
import unittest
from pathlib import Path
from tool import version_sync


class VersionSyncTests(unittest.TestCase):
    def setUp(self):
        scratch = version_sync.ROOT / '.local'
        scratch.mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=scratch)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'pubspec.yaml').write_text('name: worthhit\nversion: 1.0.0\n')
        (self.root / 'CHANGELOG.md').write_text('## [1.0.0] - 2026-10-20\n\nRelease.\n')
        (self.root / 'lib/app').mkdir(parents=True)
        (self.root / 'lib/app/app_identity.dart').write_text('old identity')
        for target in version_sync.HTML_TARGETS:
            page = self.root / target
            page.parent.mkdir(parents=True, exist_ok=True)
            page.write_text('<p>History 0.2.0</p><span data-app-version>0.2.0</span>')

    def test_check_detects_drift_without_writing_then_sync_updates_only_markers(self):
        changed = version_sync.synchronize(self.root)
        self.assertEqual(len(changed), 4)
        self.assertEqual((self.root / 'lib/app/app_identity.dart').read_text(), 'old identity')
        version_sync.synchronize(self.root, write=True)
        self.assertEqual(version_sync.synchronize(self.root), [])
        for target in version_sync.HTML_TARGETS:
            self.assertEqual((self.root / target).read_text(),
                             '<p>History 0.2.0</p><span data-app-version>1.0.0</span>')

    def test_missing_or_duplicated_marker_fails_before_any_write(self):
        for html in ('<p>no version</p>', '<span data-app-version>0.2.0</span>' * 2):
            page = self.root / version_sync.HTML_TARGETS[-1]
            page.write_text(html)
            with self.assertRaisesRegex(ValueError, 'exactly one'):
                version_sync.synchronize(self.root, write=True)
            self.assertEqual((self.root / 'lib/app/app_identity.dart').read_text(), 'old identity')

    def test_version_requires_dated_release_notes(self):
        (self.root / 'pubspec.yaml').write_text('version: 1.0.1\n')
        with self.assertRaises(ValueError):
            version_sync.synchronize(self.root, write=True)
        self.assertEqual((self.root / 'lib/app/app_identity.dart').read_text(), 'old identity')


if __name__ == '__main__':
    unittest.main()
