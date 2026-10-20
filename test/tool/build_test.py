import importlib.util
import hashlib
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

    def test_repeated_builds_remove_obsolete_public_assets_without_touching_other_files(self):
        build = load("build")
        with tempfile.TemporaryDirectory(dir=ROOT / ".local") as tmp:
            root = Path(tmp)
            output = root / "build/web"
            output.mkdir(parents=True)
            sibling = root / "build/compiler-cache"
            sibling.write_bytes(b"keep compiler cache")
            source = root / "source-font.ttf"
            source.write_bytes(b"keep original font")

            def compile(command, *, cwd, check):
                self.assertEqual(cwd, root)
                self.assertTrue(check)
                self.assertEqual(command[1:3], ["build", "web"])
                self.assertFalse(output.exists(), "Flutter must receive a clean public output directory")
                (output / "assets").mkdir(parents=True)
                (output / "assets/current.woff2").write_bytes(b"current font")

            with patch.object(build, "ROOT", root), patch.object(build.subprocess, "run", side_effect=compile) as run:
                for _ in range(2):
                    (output / "obsolete.ttf").write_bytes(b"stale previous font")
                    (output / "removed-page.html").write_text("old public page")
                    (output / "linked-source.ttf").symlink_to(source)
                    build.compile_web("/")
                    self.assertEqual(set(build.manifest_for(output)), {"assets/current.woff2"})
                self.assertEqual(run.call_count, 2)
            self.assertEqual(source.read_bytes(), b"keep original font")
            self.assertEqual(sibling.read_bytes(), b"keep compiler cache")

    def test_clean_build_rejects_redirected_or_non_directory_output_without_mutation(self):
        build = load("build")
        for problem in ["build_symlink", "build_file", "web_symlink", "web_file"]:
            with self.subTest(problem=problem), tempfile.TemporaryDirectory(dir=ROOT / ".local") as tmp:
                root = Path(tmp)
                target = root / "preserved"
                target.mkdir()
                sentinel = target / "keep.txt"
                sentinel.write_text("must survive")
                if problem == "build_symlink":
                    (root / "build").symlink_to(target, target_is_directory=True)
                elif problem == "build_file":
                    (root / "build").write_text("not a build directory")
                else:
                    (root / "build").mkdir()
                    if problem == "web_symlink":
                        (root / "build/web").symlink_to(target, target_is_directory=True)
                    else:
                        (root / "build/web").write_text("not an output directory")
                with patch.object(build, "ROOT", root), patch.object(build.subprocess, "run") as run:
                    with self.assertRaises(ValueError):
                        build.compile_web("/")
                    run.assert_not_called()
                self.assertEqual(sentinel.read_text(), "must survive")
                if problem == "web_file":
                    self.assertEqual((root / "build/web").read_text(), "not an output directory")

    def renderer_fixture(self, root, *, build_overrides=None, runtime_overrides=None):
        keep = {"canvaskit.js", "canvaskit.wasm", "chromium/canvaskit.js", "chromium/canvaskit.wasm"}
        extras = {"canvaskit.js.symbols", "chromium/canvaskit.js.symbols"}
        for name in ["skwasm", "skwasm_heavy", "wimp", "webparagraph/canvaskit"]:
            extras.update({name + ".js", name + ".wasm", name + ".js.symbols"})
        for name in keep | extras:
            path = root / "canvaskit" / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(name.encode())
        config = {"engineRevision": "a" * 40, "useLocalCanvasKit": True,
                  "wasmHashes": {name: hashlib.sha256(name.encode()).hexdigest()
                                 for name in keep | extras if name.endswith(".wasm")},
                  "builds": [{"compileTarget": "dart2js", "renderer": "canvaskit",
                              "mainJsPath": "main.dart.js"}, {}]}
        config.update(build_overrides or {})
        runtime = {"renderer": "canvaskit", "canvasKitVariant": "auto", "preferWebParagraph": False}
        runtime.update(runtime_overrides or {})
        (root / "flutter_bootstrap.js").write_text(
            "_flutter.buildConfig = " + json.dumps(config) + ";\n"
            "const worthhitRendererConfig = " + json.dumps(runtime) + ";\n"
            "_flutter.loader.load({config: worthhitRendererConfig, onEntrypointLoaded: async function(engineInitializer) {\n"
            "await engineInitializer.initializeEngine(worthhitRendererConfig);\n}});\n")
        return keep, extras

    def test_prune_keeps_both_supported_canvaskit_variants_and_only_removes_known_extras(self):
        build = load("build")
        with tempfile.TemporaryDirectory(dir=ROOT / ".local") as tmp:
            root = Path(tmp)
            keep, extras = self.renderer_fixture(root)
            (root / "main.dart.js").write_text("application")
            removed = build.prune_renderers(root)
            self.assertEqual(removed, sum(len(name.encode()) for name in extras))
            self.assertEqual({p.relative_to(root / "canvaskit").as_posix()
                              for p in (root / "canvaskit").rglob("*") if p.is_file()}, keep)
            self.assertEqual((root / "main.dart.js").read_text(), "application")
            self.assertEqual(build.prune_renderers(root), 0)

    def test_unsupported_renderer_configuration_fails_before_removing_files(self):
        build = load("build")
        cases = [
            {"build_overrides": {"builds": [{"compileTarget": "dart2wasm", "renderer": "skwasm"}]}},
            {"build_overrides": {"builds": []}},
            {"build_overrides": {"useLocalCanvasKit": False}},
            {"build_overrides": {"newRendererSetting": True}},
            {"runtime_overrides": {"preferWebParagraph": True}},
            {"runtime_overrides": {"renderer": "skwasm"}},
            {"runtime_overrides": {"unknownOption": True}},
        ]
        for options in cases:
            with self.subTest(options=options), tempfile.TemporaryDirectory(dir=ROOT / ".local") as tmp:
                root = Path(tmp)
                self.renderer_fixture(root, **options)
                before = build.manifest_for(root)
                with self.assertRaises(ValueError):
                    build.prune_renderers(root)
                self.assertEqual(build.manifest_for(root), before)

    def test_unknown_assets_missing_required_assets_and_unbound_runtime_fail_closed(self):
        build = load("build")
        for problem in ["unknown", "missing", "unbound", "unbound_engine", "mutated", "bad_hash"]:
            with self.subTest(problem=problem), tempfile.TemporaryDirectory(dir=ROOT / ".local") as tmp:
                root = Path(tmp)
                self.renderer_fixture(root)
                bootstrap = root / "flutter_bootstrap.js"
                if problem == "unknown":
                    (root / "canvaskit/future-renderer.wasm").write_bytes(b"unrecognized")
                elif problem == "missing":
                    (root / "canvaskit/canvaskit.js").unlink()
                elif problem == "unbound":
                    bootstrap.write_text(bootstrap.read_text().replace("config: worthhitRendererConfig", "config: anotherConfig"))
                elif problem == "unbound_engine":
                    bootstrap.write_text(bootstrap.read_text().replace("initializeEngine(worthhitRendererConfig)", "initializeEngine()"))
                elif problem == "mutated":
                    bootstrap.write_text(bootstrap.read_text() + "worthhitRendererConfig.preferWebParagraph = true;")
                else:
                    (root / "canvaskit/canvaskit.wasm").write_bytes(b"unexpected wasm")
                before = build.manifest_for(root)
                with self.assertRaises(ValueError):
                    build.prune_renderers(root)
                self.assertEqual(build.manifest_for(root), before)

    def test_public_bootstrap_has_only_the_owned_google_tag_and_no_api_secrets(self):
        index = (ROOT / "web/index.html").read_text()
        self.assertEqual(index.count('https://www.googletagmanager.com/gtag/js?id=G-G4SYW37S81'), 1)
        self.assertNotIn("G-P3K2ZN7YTL", index)
        self.assertFalse(load("repository_check").contains_secret(index.encode()))
        self.assertNotIn("wfform.com", index)
        self.assertIn("Worthhit", index)


if __name__ == "__main__":
    unittest.main()
