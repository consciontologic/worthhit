import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tool" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class BuildTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        (ROOT / ".local").mkdir(exist_ok=True)

    def test_manifest_hashes_actual_assets_and_excludes_worker(self):
        build = load("build")
        with tempfile.TemporaryDirectory(dir=ROOT / ".local") as tmp:
            root = Path(tmp)
            (root / "pwa_bootstrap.js").write_text("const version='__BUILD_ID__';")
            (root / "index.html").write_text("<title>Worthit</title>")
            (root / "flutter_service_worker.js").write_text("legacy")
            version = build.package(root)
            release = json.loads((root / "release.json").read_text())
            self.assertEqual(len(version), 64)
            self.assertEqual(release["assets"], build.manifest_for(root))
            self.assertNotIn("service_worker.js", release["assets"])
            self.assertNotIn("__BUILD_ID__", (root / "pwa_bootstrap.js").read_text())
            self.assertFalse((root / "flutter_service_worker.js").exists())

    def test_worker_only_changes_get_a_new_generation(self):
        build = load("build")
        with tempfile.TemporaryDirectory(dir=ROOT / ".local") as tmp:
            root = Path(tmp)
            (root / "web").mkdir()
            template = root / "web/service_worker.js"
            template.write_text("const version='__BUILD_ID__'; const assets=__PRECACHE_MANIFEST__;")
            versions = []
            with patch.object(build, "ROOT", root):
                for i in range(2):
                    output = root / str(i)
                    output.mkdir()
                    (output / "pwa_bootstrap.js").write_text("const version='__BUILD_ID__';")
                    (output / "index.html").write_text("Same application")
                    versions.append(build.package(output))
                    template.write_text(template.read_text() + "\n// worker fix")
            self.assertNotEqual(*versions)

    def test_public_manifest_excludes_files_omitted_by_pages_archive(self):
        build = load("build")
        with tempfile.TemporaryDirectory(dir=ROOT / ".local") as tmp:
            root = Path(tmp)
            (root / "pwa_bootstrap.js").write_text("const version='__BUILD_ID__';")
            (root / "index.html").write_text("<title>Worthit</title>")
            (root / ".last_build_id").write_text("flutter build metadata")
            (root / ".private").mkdir()
            (root / ".private/metadata").write_text("not published")
            (root / "assets").mkdir()
            (root / "assets/.metadata").write_text("not published")
            (root / "assets/.cache").mkdir()
            (root / "assets/.cache/file").write_text("not published")
            (root / "assets/font.woff2").write_bytes(b"font")
            version = build.package(root)
            release = json.loads((root / "release.json").read_text())
            self.assertEqual(
                set(release["assets"]),
                {"index.html", "pwa_bootstrap.js", "assets/font.woff2"},
            )
            worker = (root / "service_worker.js").read_text()
            self.assertNotIn(".last_build_id", worker)
            self.assertNotIn(".private", worker)
            self.assertNotIn(".metadata", worker)
            self.assertNotIn(".cache", worker)
            (root / ".last_build_id").write_text("new local build metadata")
            (root / "pwa_bootstrap.js").write_text("const version='__BUILD_ID__';")
            self.assertEqual(version, build.package(root))

    def test_secret_detector_fails_closed_without_printing_values(self):
        check = load("repository_check")
        self.assertTrue(check.contains_secret(b"sk-or-v1-" + b"a" * 64))
        self.assertTrue(check.contains_secret(b"github_pat_" + b"B" * 60))
        self.assertFalse(check.contains_secret(b"OPENROUTER_API_KEY"))

    def test_public_bootstrap_has_only_the_owned_google_tag_and_no_api_secrets(self):
        index = (ROOT / "web/index.html").read_text()
        self.assertEqual(index.count('https://www.googletagmanager.com/gtag/js?id=G-G4SYW37S81'), 1)
        self.assertNotIn("G-P3K2ZN7YTL", index)
        self.assertFalse(load("repository_check").contains_secret(index.encode()))
        self.assertNotIn("wfform.com", index)
        self.assertIn("Worthhit", index)


if __name__ == "__main__":
    unittest.main()
