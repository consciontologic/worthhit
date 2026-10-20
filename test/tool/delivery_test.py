import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'tool' / f'{name}.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class DeliveryTests(unittest.TestCase):
    def setUp(self):
        self.release = load('release')
        self.website = load('publish_website')
        self.tmp = tempfile.TemporaryDirectory(dir=ROOT / '.local')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def site(self):
        root = self.root / 'site'
        root.mkdir()
        (root / 'index.html').write_text('app')
        (root / 'service_worker.js').write_text('worker')
        (root / 'release.json').write_text(json.dumps({
            'version': 'a' * 64, 'app_version': '0.2.0', 'source_sha': 'b' * 40,
            'repository': 'consciontologic/worthhit',
            'assets': {'index.html': self.release.fingerprint(root / 'index.html')},
        }))
        return root

    def test_plain_semver_and_dated_release_notes(self):
        (self.root / 'pubspec.yaml').write_text('name: worthhit\nversion: 0.2.0\n')
        (self.root / 'CHANGELOG.md').write_text('# Changelog\n\n## [0.2.0] - 2026-10-20\n\nNew app.\n')
        self.assertEqual(self.release.release_version(self.root), '0.2.0')
        for version in ['v0.2.0', '00.2.0', '0.2.0+1', '0.2.0-beta']:
            (self.root / 'pubspec.yaml').write_text('version: ' + version + '\n')
            with self.assertRaises(ValueError):
                self.release.release_version(self.root)
        (self.root / 'pubspec.yaml').write_text('version: 0.2.0\n')
        (self.root / 'CHANGELOG.md').write_text('## [0.2.0] - 2026-02-30\n')
        with self.assertRaises(ValueError):
            self.release.release_version(self.root)

    def test_site_integrity_is_checked_before_publication(self):
        site = self.site()
        self.assertEqual(set(self.release.verify_site(site)), {'index.html', 'release.json', 'service_worker.js'})
        (site / 'index.html').write_text('changed')
        with self.assertRaisesRegex(ValueError, 'integrity'):
            self.release.verify_site(site)

    def test_site_rejects_unsafe_paths_symlinks_and_unlisted_files(self):
        site = self.site()
        release = json.loads((site / 'release.json').read_text())
        release['assets']['../escape'] = release['assets']['index.html']
        (site / 'release.json').write_text(json.dumps(release))
        with self.assertRaisesRegex(ValueError, 'path'):
            self.release.verify_site(site)
        del release['assets']['../escape']
        (site / 'release.json').write_text(json.dumps(release))
        (site / 'extra.txt').write_text('unlisted')
        with self.assertRaisesRegex(ValueError, 'Unlisted'):
            self.release.verify_site(site)
        (site / 'extra.txt').unlink()
        (site / 'index.html').unlink()
        (site / 'index.html').symlink_to(site / 'service_worker.js')
        with self.assertRaisesRegex(ValueError, 'Symlink'):
            self.release.verify_site(site)

    def test_website_preserves_unrelated_and_rejects_edited_managed_files(self):
        site = self.site()
        destination = self.root / 'destination'
        destination.mkdir()
        (destination / 'README.md').write_text('Owner notes')
        changed = self.website.prepare(site, destination)
        self.assertIn('CNAME', changed)
        self.assertEqual((destination / 'CNAME').read_text(), 'worthhit.com\n')
        self.assertEqual((destination / 'README.md').read_text(), 'Owner notes')
        self.assertEqual(self.website.prepare(site, destination), [])
        (destination / 'index.html').write_text('Owner edit')
        with self.assertRaisesRegex(ValueError, 'edited'):
            self.website.prepare(site, destination)
        self.assertEqual((destination / 'index.html').read_text(), 'Owner edit')

    def test_website_rejects_unowned_collision_before_writing_anything(self):
        site = self.site()
        destination = self.root / 'destination'
        destination.mkdir()
        (destination / 'index.html').write_text('Someone else')
        with self.assertRaisesRegex(ValueError, 'Unowned'):
            self.website.prepare(site, destination)
        self.assertEqual(list(destination.iterdir()), [destination / 'index.html'])

    def test_website_rejects_symlink_ancestor_and_foreign_ownership(self):
        site = self.site()
        destination = self.root / 'destination'
        destination.mkdir()
        (destination / 'index.html').symlink_to(site / 'index.html')
        with self.assertRaisesRegex(ValueError, 'Symlink'):
            self.website.prepare(site, destination)
        (destination / 'index.html').unlink()
        self.website.prepare(site, destination)
        manifest = destination / '.worthhit-deploy.json'
        data = json.loads(manifest.read_text())
        data['repository'] = 'other/project'
        manifest.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, 'ownership'):
            self.website.prepare(site, destination)

    def test_source_sha_accepts_only_validated_pr_head_or_exact_dispatch_sha(self):
        from unittest.mock import patch
        sha = 'b' * 40
        event = self.root / 'event.json'
        event.write_text(json.dumps({'pull_request': {'head': {'sha': sha},
                         'base': {'repo': {'full_name': 'consciontologic/worthhit'}}}}))
        env = {'GITHUB_EVENT_NAME': 'pull_request', 'GITHUB_SHA': 'c' * 40,
               'GITHUB_EVENT_PATH': str(event), 'GITHUB_REPOSITORY': 'consciontologic/worthhit'}
        with patch.object(self.release.subprocess, 'check_output', return_value=sha + '\n'), \
                patch.dict(self.release.os.environ, env, clear=True):
            self.assertEqual(self.release.source_sha(), sha)
            event.write_text(json.dumps({'pull_request': {'head': {'sha': 'd' * 40},
                         'base': {'repo': {'full_name': 'consciontologic/worthhit'}}}}))
            with self.assertRaisesRegex(ValueError, 'source'):
                self.release.source_sha()
        with patch.object(self.release.subprocess, 'check_output', return_value=sha + '\n'), \
                patch.dict(self.release.os.environ, {'GITHUB_EVENT_NAME': 'workflow_dispatch',
                    'GITHUB_SHA': 'c' * 40}, clear=True):
            with self.assertRaisesRegex(ValueError, 'source'):
                self.release.source_sha()
            self.release.os.environ['GITHUB_SHA'] = sha
            self.assertEqual(self.release.source_sha(), sha)

    def test_archive_is_deterministic_and_preserves_exact_verified_members(self):
        import tarfile
        site = self.site()
        first, second = self.root / 'first.tar.gz', self.root / 'second.tar.gz'
        files = self.release.archive_site(site, first)
        self.release.archive_site(site, second)
        self.assertEqual(first.read_bytes(), second.read_bytes())
        with tarfile.open(first) as archive:
            self.assertEqual(set(archive.getnames()), set(files))
            for member in archive:
                self.assertTrue(member.isfile())
                self.assertEqual(archive.extractfile(member).read(), (site / member.name).read_bytes())

    def test_old_owned_files_are_removed_without_touching_unrelated_files(self):
        site = self.site()
        destination = self.root / 'destination'
        destination.mkdir()
        release = json.loads((site / 'release.json').read_text())
        (site / 'old.js').write_text('old')
        release['assets']['old.js'] = self.release.fingerprint(site / 'old.js')
        (site / 'release.json').write_text(json.dumps(release))
        self.website.prepare(site, destination)
        (destination / 'notes.txt').write_text('keep')
        (site / 'old.js').unlink()
        del release['assets']['old.js']
        (site / 'release.json').write_text(json.dumps(release))
        self.assertIn('old.js', self.website.prepare(site, destination))
        self.assertFalse((destination / 'old.js').exists())
        self.assertEqual((destination / 'notes.txt').read_text(), 'keep')

    def test_authenticated_draft_lookup_recovers_tag_endpoint_miss(self):
        base = '/repos/consciontologic/worthhit'
        draft = {'id': 73, 'tag_name': '0.2.0', 'draft': True}
        def api(path, optional=False):
            if path == base + '/releases/tags/0.2.0':
                return None
            if path == base + '/releases?per_page=100&page=1':
                return [draft]
            self.fail('Unexpected API request: ' + path)
        self.assertEqual(self.release.find_release(base, '0.2.0', api), draft)
        def duplicates(path, optional=False):
            if '/releases/tags/' in path:
                return None
            return [draft, {**draft, 'id': 74}]
        with self.assertRaisesRegex(ValueError, 'Multiple'):
            self.release.find_release(base, '0.2.0', duplicates)

    def test_partial_draft_resume_reuses_id_and_uploads_only_missing_asset(self):
        from unittest.mock import patch
        from tool import release_guard
        output = self.root / 'bundle'
        output.mkdir()
        for name in ['release-identity.json', 'SHA256SUMS', 'release-notes.md']:
            (output / name).write_text(name)
        expected = {p.name: self.release.fingerprint(p) for p in output.iterdir()}
        sha = 'b' * 40
        base = '/repos/consciontologic/worthhit'
        draft = {'id': 73, 'tag_name': '0.2.0', 'name': 'Worthhit 0.2.0', 'draft': True,
                 'body': 'Source: consciontologic/worthhit@' + sha}
        writes = []
        def api(path, data=None, method='GET', optional=False, binary=None):
            if method != 'GET':
                writes.append((path, method, data, binary))
                if method == 'POST':
                    return {'digest': 'sha256:' + expected['release-notes.md']['sha256']}
                return {**draft, 'draft': False}
            if path == base + '/git/ref/tags/0.2.0':
                return {'object': {'type': 'commit', 'sha': sha}}
            if path == base + '/releases/tags/0.2.0':
                return None
            if path == base + '/releases?per_page=100&page=1':
                return [draft]
            if path == base + '/releases/73/assets?per_page=100':
                return [{'name': name, 'state': 'uploaded', 'size': expected[name]['bytes'],
                         'digest': 'sha256:' + expected[name]['sha256']}
                        for name in ['release-identity.json', 'SHA256SUMS']]
            self.fail('Unexpected API request ' + path)
        identity = {'version': '0.2.0', 'source_sha': sha,
                    'artifacts': {'release-notes.md': expected['release-notes.md']}}
        with patch.object(self.release, 'verify_bundle', return_value=identity), \
                patch.object(self.release, 'api', api), patch.object(release_guard, 'approval'):
            self.release.publish(output, apply=True)
        self.assertEqual([(path, method) for path, method, _, _ in writes], [
            (base + '/releases/73/assets?name=release-notes.md', 'POST'),
            (base + '/releases/73', 'PATCH')])
        self.assertEqual(writes[0][3], (output / 'release-notes.md').read_bytes())
        self.assertEqual(writes[1][2], {
            'name': '0.2.0', 'draft': False, 'make_latest': 'false'})

    def test_new_release_creation_and_publication_use_plain_semver_names(self):
        from unittest.mock import patch
        from tool import release_guard
        output = self.root / 'bundle'
        output.mkdir()
        sha = 'b' * 40
        notes = 'Release notes.\n\nSource: consciontologic/worthhit@' + sha + '\n'
        for name in ['release-identity.json', 'SHA256SUMS']:
            (output / name).write_text(name)
        (output / 'release-notes.md').write_text(notes)
        expected = {p.name: self.release.fingerprint(p) for p in output.iterdir()}
        base = '/repos/consciontologic/worthhit'
        writes = []
        def api(path, data=None, method='GET', optional=False, binary=None):
            if method != 'GET':
                writes.append((path, method, data, binary))
                if path == base + '/git/refs':
                    return {}
                if path == base + '/releases':
                    return {'id': 73, **data}
                if path.startswith(base + '/releases/73/assets?name='):
                    name = path.split('?name=', 1)[1]
                    return {'digest': 'sha256:' + expected[name]['sha256']}
                if path == base + '/releases/73' and method == 'PATCH':
                    return {'id': 73, **data}
                self.fail('Unexpected API write: ' + path)
            if path in [base + '/git/ref/tags/1.0.0', base + '/releases/tags/1.0.0']:
                return None
            if path == base + '/releases?per_page=100&page=1':
                return []
            self.fail('Unexpected API request: ' + path)
        identity = {'version': '1.0.0', 'source_sha': sha,
                    'artifacts': {'release-notes.md': expected['release-notes.md']}}
        with patch.object(self.release, 'verify_bundle', return_value=identity), \
                patch.object(self.release, 'api', api), \
                patch.object(release_guard, 'approval') as approval:
            self.release.publish(output, apply=True)
        approval.assert_called_once_with()
        self.assertEqual(writes[0], (base + '/git/refs', 'POST', {
            'ref': 'refs/tags/1.0.0', 'sha': sha}, None))
        self.assertEqual(writes[1], (base + '/releases', 'POST', {
            'tag_name': '1.0.0', 'target_commitish': sha, 'name': '1.0.0',
            'draft': True, 'prerelease': False, 'body': notes}, None))
        self.assertEqual(writes[-1], (base + '/releases/73', 'PATCH', {
            'name': '1.0.0', 'draft': False, 'make_latest': 'false'}, None))

    def test_release_resume_accepts_only_exact_source_and_asset_bytes(self):
        expected = {'release-identity.json': {'bytes': 4, 'sha256': 'a' * 64}}
        tag = {'object': {'type': 'commit', 'sha': 'b' * 40}}
        release = {'tag_name': '0.2.0', 'draft': True,
                   'body': 'Source: consciontologic/worthhit@' + 'b' * 40,
                   'assets': [{'name': 'release-identity.json', 'size': 4,
                               'state': 'uploaded', 'digest': 'sha256:' + 'a' * 64}]}
        self.assertEqual(self.release.release_plan('0.2.0', 'b' * 40, tag, release, expected), [])
        release['assets'][0]['digest'] = 'sha256:' + 'c' * 64
        with self.assertRaisesRegex(ValueError, 'asset'):
            self.release.release_plan('0.2.0', 'b' * 40, tag, release, expected)
        tag['object']['sha'] = 'c' * 40
        with self.assertRaisesRegex(ValueError, 'tag'):
            self.release.release_plan('0.2.0', 'b' * 40, tag, release, expected)

    def test_published_release_cannot_be_extended_or_replaced(self):
        expected = {'release-identity.json': {'bytes': 4, 'sha256': 'a' * 64}}
        tag = {'object': {'type': 'commit', 'sha': 'b' * 40}}
        release = {'tag_name': '0.2.0', 'draft': False, 'assets': [],
                   'body': 'Source: consciontologic/worthhit@' + 'b' * 40}
        with self.assertRaisesRegex(ValueError, 'Published'):
            self.release.release_plan('0.2.0', 'b' * 40, tag, release, expected)


if __name__ == '__main__':
    unittest.main()
