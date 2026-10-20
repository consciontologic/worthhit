import tempfile
import unittest
from pathlib import Path
from tool import information_sync


class InformationSyncTests(unittest.TestCase):
    def test_all_canonical_documents_retain_full_blocks_and_links(self):
        documents = information_sync.documents()
        self.assertEqual(set(documents), {'about', 'terms', 'liability'})
        self.assertEqual([len(documents[key]['sections']) for key in documents], [6, 7, 5])
        about = documents['about']
        self.assertEqual(about['sections'][0]['blocks'][0]['type'], 'ordered')
        spans = [span for doc in documents.values() for section in doc['sections']
                 for block in section['blocks'] for paragraph in block['paragraphs'] for span in paragraph]
        self.assertIn('/terms?section=data', [s.get('href') for s in spans])
        self.assertIn('https://policies.google.com/privacy', [s.get('href') for s in spans])
        self.assertIn('“as is” and “as available”', [s['text'] for s in spans if s.get('strong')])
        self.assertTrue(all(doc['title'] and doc['lead'] and doc['updated'] for doc in documents.values()))

    def test_rejects_unknown_or_unsafe_content_instead_of_dropping_it(self):
        original = (information_sync.ROOT / 'web/about/index.html').read_text()
        for replacement in ('<p><script>secret()</script></p>', '<p><em>new formatting</em></p>',
                            '<p><a href="javascript:alert(1)">Unsafe</a></p>'):
            altered = original.replace('<section id="method">', '<section id="method">' + replacement)
            with self.assertRaises(ValueError):
                information_sync.parse_document(altered, 'about')

    def test_generation_is_checked_and_only_replaces_owned_output(self):
        with tempfile.TemporaryDirectory(dir=information_sync.ROOT / '.local') as directory:
            root = Path(directory)
            for name in information_sync.NAMES:
                dest = root / f'web/{name}/index.html'
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_text((information_sync.ROOT / f'web/{name}/index.html').read_text())
            target = root / information_sync.TARGET
            self.assertTrue(information_sync.synchronize(root))
            self.assertFalse(target.exists())
            information_sync.synchronize(root, write=True)
            self.assertFalse(information_sync.synchronize(root))
            target.write_text(target.read_text() + '// stale\n')
            self.assertTrue(information_sync.synchronize(root))
