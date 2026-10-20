import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def load():
    spec = importlib.util.spec_from_file_location('container', ROOT / 'tool/container.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ContainerTests(unittest.TestCase):
    def test_nginx_base_uses_official_hub_with_an_immutable_pin(self):
        dockerfile = (ROOT / 'Dockerfile').read_text()
        bases = [line for line in dockerfile.splitlines() if line.startswith('FROM ')]
        self.assertEqual(len(bases), 1)
        self.assertRegex(
            bases[0],
            r'^FROM docker\.io/library/nginx:\d+\.\d+\.\d+-alpine@sha256:[0-9a-f]{64}$',
        )

    def test_existing_container_tag_must_match_exact_image(self):
        container = load()
        with patch.object(container, 'remote_exists', return_value=True), \
                patch.object(container, 'run'), \
                patch.object(container, 'image_id', return_value='sha256:other'):
            with self.assertRaisesRegex(ValueError, 'immutable'):
                container.registry_preflight('tag', 'sha256:approved')
        with patch.object(container, 'remote_exists', return_value=True), \
                patch.object(container, 'run'), \
                patch.object(container, 'image_id', return_value='sha256:approved'):
            self.assertTrue(container.registry_preflight('tag', 'sha256:approved'))

    def test_stale_web_build_cannot_enter_an_approved_image(self):
        container = load()
        with patch.object(container, 'verify_bundle', return_value={'files': {'index.html': 'approved'}}), \
                patch.object(container, 'verify_site', return_value={'index.html': 'different'}), \
                patch.object(container, 'context', side_effect=AssertionError('Docker context created before identity check')):
            with self.assertRaisesRegex(ValueError, 'differs'):
                container.build()

    def test_registry_failure_is_not_treated_as_absent_image(self):
        container = load()
        from subprocess import CompletedProcess
        with patch.object(container.subprocess, 'run', return_value=CompletedProcess([], 1, '', 'unauthorized')):
            with self.assertRaisesRegex(RuntimeError, 'Registry'):
                container.remote_exists('tag')
        with patch.object(container.subprocess, 'run', return_value=CompletedProcess([], 1, '', 'manifest unknown')):
            self.assertFalse(container.remote_exists('tag'))

    def test_nginx_csp_permits_only_the_exact_static_json_ld(self):
        import base64
        import hashlib
        import re
        index = (ROOT / 'web/index.html').read_text()
        metadata = re.findall(r'<script type="application/ld\+json">(.*?)</script>', index, re.S)
        self.assertEqual(len(metadata), 1)
        digest = base64.b64encode(hashlib.sha256(metadata[0].encode()).digest()).decode()
        self.assertIn("'sha256-" + digest + "'", (ROOT / 'deploy/nginx/headers.conf').read_text())

    def test_container_is_static_non_root_and_has_no_repository_context(self):
        dockerfile = (ROOT / 'Dockerfile').read_text()
        config = (ROOT / 'deploy/nginx/server.conf').read_text()
        self.assertIn('@sha256:', dockerfile)
        self.assertIn('USER 101:101', dockerfile)
        self.assertIn('COPY site/', dockerfile)
        self.assertNotIn('COPY . ', dockerfile)
        self.assertIn('=404', config)
        self.assertIn('GET|HEAD', config)
        self.assertNotIn('proxy_pass', config)
        nginx = (ROOT / 'deploy/nginx/nginx.conf').read_text()
        self.assertNotIn('$request_uri', nginx)
        self.assertNotIn('$args', nginx)
        self.assertNotIn('$request ', nginx)


if __name__ == '__main__':
    unittest.main()
