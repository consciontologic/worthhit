"""Build a static, credential-free, hash-verified Worthhit PWA."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-href", default="/")
    args = parser.parse_args()
    if not re.fullmatch(r"/(?:[A-Za-z0-9_-]+/)*", args.base_href):
        parser.error("base href must be an absolute directory path")
    subprocess.run(
        [os.environ.get("FLUTTER", "flutter"), "build", "web", "--release", "--no-pub",
         "--no-web-resources-cdn", "--pwa-strategy=none", "--base-href", args.base_href],
        cwd=ROOT, check=True,
    )
    import sys
    sys.path.insert(0, str(ROOT))
    from tool.release import REPOSITORY, release_version, source_sha
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
