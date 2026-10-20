"""Build a static, credential-free, hash-verified Worthhit PWA."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CANVASKIT_REQUIRED = {
    "canvaskit.js", "canvaskit.wasm", "chromium/canvaskit.js", "chromium/canvaskit.wasm",
}
CANVASKIT_UNUSED = {"canvaskit.js.symbols", "chromium/canvaskit.js.symbols"} | {
    name + suffix
    for name in ("skwasm", "skwasm_heavy", "wimp", "webparagraph/canvaskit")
    for suffix in (".js", ".wasm", ".js.symbols")
}


def _json_assignment(source, marker):
    if source.count(marker) != 1:
        raise ValueError("Unsupported renderer bootstrap assignment")
    value, _ = json.JSONDecoder().raw_decode(source.split(marker, 1)[1].lstrip())
    return value


def prune_renderers(directory):
    """Trim only unused variants of the pinned dart2js/CanvasKit build, fail closed."""
    source = (directory / "flutter_bootstrap.js").read_text()
    config = _json_assignment(source, "_flutter.buildConfig =")
    runtime = _json_assignment(source, "const worthhitRendererConfig =")
    supported = {"compileTarget": "dart2js", "renderer": "canvaskit", "mainJsPath": "main.dart.js"}
    if (not isinstance(config, dict)
            or set(config) != {"engineRevision", "wasmHashes", "builds", "useLocalCanvasKit"}
            or config["builds"] not in ([supported], [supported, {}])
            or config["useLocalCanvasKit"] is not True
            or not isinstance(config["engineRevision"], str)
            or not re.fullmatch(r"[0-9a-f]{40}", config["engineRevision"])):
        raise ValueError("Unsupported Flutter build; renderer pruning requires local dart2js/CanvasKit")
    if (runtime != {"renderer": "canvaskit", "canvasKitVariant": "auto", "preferWebParagraph": False}
            or runtime.get("preferWebParagraph") is not False
            or source.count("worthhitRendererConfig") != 3
            or source.count("_flutter.loader.load(") != 1
            or source.count("engineInitializer.initializeEngine(worthhitRendererConfig)") != 1
            or not re.search(r"_flutter\.loader\.load\(\{\s*config:\s*worthhitRendererConfig,\s*onEntrypointLoaded:", source)):
        raise ValueError("Unsupported runtime renderer configuration")
    hashes = config["wasmHashes"]
    wasm_names = {name for name in CANVASKIT_REQUIRED | CANVASKIT_UNUSED if name.endswith(".wasm")}
    if (not isinstance(hashes, dict) or set(hashes) != wasm_names
            or any(not isinstance(value, str) or not re.fullmatch(r"[0-9a-f]{64}", value)
                   for value in hashes.values())):
        raise ValueError("Unsupported renderer integrity metadata")
    renderer = directory / "canvaskit"
    paths = list(renderer.rglob("*"))
    files = {path.relative_to(renderer).as_posix() for path in paths if path.is_file()}
    if (any(path.is_symlink() for path in paths)
            or not CANVASKIT_REQUIRED <= files
            or files - CANVASKIT_REQUIRED - CANVASKIT_UNUSED):
        raise ValueError("Missing or unrecognized renderer files; nothing was removed")
    for name in CANVASKIT_REQUIRED:
        if name.endswith(".wasm") and hashlib.sha256((renderer / name).read_bytes()).hexdigest() != hashes[name]:
            raise ValueError("Required CanvasKit bytes do not match the build integrity metadata")
    # All checks finish before the first mutation. Keep both full and Chromium
    # variants: Safari/Firefox cannot use the Chromium-only renderer.
    removed = 0
    for name in sorted(files & CANVASKIT_UNUSED):
        path = renderer / name
        removed += path.stat().st_size
        path.unlink()
    for path in sorted(renderer.rglob("*"), reverse=True):
        if path.is_dir() and not any(path.iterdir()):
            path.rmdir()
    return removed


def manifest_for(directory):
    return {
        path.relative_to(directory).as_posix(): {
            "bytes": path.stat().st_size,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        }
        for path in sorted(directory.rglob("*"))
        if path.is_file()
        # upload-pages-artifact excludes hidden path components. They cannot be
        # required by the all-or-nothing offline shell (e.g. .last_build_id).
        and not any(part.startswith(".") for part in path.relative_to(directory).parts)
        and path.name not in {"service_worker.js", "flutter_service_worker.js", "release.json"}
    }


def package(directory, metadata=None):
    worker = directory / "flutter_service_worker.js"
    if worker.exists():
        worker.unlink()
    # The generation hash is over the unpersonalized static build. Substitute it
    # before the final byte manifest, avoiding a self-referential content digest.
    template = (ROOT / "web/service_worker.js").read_text()
    identity = {"assets": manifest_for(directory), "worker_template": template}
    version = hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()
    bootstrap = directory / "pwa_bootstrap.js"
    bootstrap.write_text(bootstrap.read_text().replace("__BUILD_ID__", version))
    assets = manifest_for(directory)
    (directory / "service_worker.js").write_text(
        template.replace("__BUILD_ID__", version).replace("__PRECACHE_MANIFEST__", json.dumps(assets))
    )
    (directory / "release.json").write_text(json.dumps({"version": version, "assets": assets, **(metadata or {})}, sort_keys=True))
    return version


def compile_web(base_href):
    # Flutter can retain removed assets in incremental web output. Only this
    # fixed public directory is disposable; keep compiler caches and sources.
    output = ROOT / "build/web"
    if (output.parent.is_symlink() or output.is_symlink()
            or output.resolve() != ROOT.resolve() / "build/web"
            or (output.parent.exists() and not output.parent.is_dir())
            or (output.exists() and not output.is_dir())):
        raise ValueError("Refusing to clean redirected or invalid build/web output")
    if output.exists():
        shutil.rmtree(output)
    subprocess.run(
        [os.environ.get("FLUTTER", "flutter"), "build", "web", "--release", "--no-pub",
         "--no-web-resources-cdn", "--pwa-strategy=none", "--base-href", base_href],
        cwd=ROOT, check=True,
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-href", default="/")
    args = parser.parse_args()
    if not re.fullmatch(r"/(?:[A-Za-z0-9_-]+/)*", args.base_href):
        parser.error("base href must be an absolute directory path")
    subprocess.run(["python3", "tool/version_sync.py"], cwd=ROOT, check=True)
    compile_web(args.base_href)
    import sys
    sys.path.insert(0, str(ROOT))
    from tool.release import REPOSITORY, release_version, source_sha
    removed = prune_renderers(ROOT / "build/web")
    print(f"Removed {removed:,} unused renderer bytes; full and Chromium CanvasKit retained.")
    # Flutter build markers are private build metadata, never public assets.
    for path in sorted((ROOT / "build/web").rglob("*"), reverse=True):
        if any(part.startswith(".") for part in path.relative_to(ROOT / "build/web").parts):
            if path.is_dir():
                path.rmdir()
            else:
                path.unlink()
    version = package(ROOT / "build/web", {"repository": REPOSITORY,
        "app_version": release_version(), "source_sha": source_sha()})
    subprocess.run(["python3", "tool/repository_check.py", "--build"], cwd=ROOT, check=True)
    print(f"Verified static build {version}; base path {args.base_href}")


if __name__ == "__main__":
    main()
