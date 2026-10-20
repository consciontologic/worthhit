"""Credential and public artifact hygiene. Never print matched secret values."""
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PATTERNS = (
    re.compile(rb"github_pat_[A-Za-z0-9_]{40,}"),
    re.compile(rb"gh[pousr]_[A-Za-z0-9]{30,}"),
    re.compile(rb"sk-or-v1-[a-fA-F0-9]{32,}"),
    re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
)


def contains_secret(data):
    return any(pattern.search(data) for pattern in PATTERNS)


def check(paths):
    failures = []
    for path in paths:
        if path.is_symlink():
            failures.append(f"Symlink is not allowed in publication: {path.name}")
        elif path.is_file():
            if contains_secret(path.read_bytes()):
                failures.append(f"Credential pattern found in {path.relative_to(ROOT)}; value withheld")
    return failures


def main():
    output = subprocess.check_output(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        cwd=ROOT,
    )
    paths = [ROOT / p.decode() for p in output.split(b"\0") if p]
    if "--build" in sys.argv:
        paths.extend((ROOT / "build/web").rglob("*"))
    failures = check(paths)
    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    print(f"Repository hygiene passed ({sum(p.is_file() for p in paths)} files).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
