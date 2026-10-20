"""Keep visible app/document versions derived from the release in pubspec.yaml."""
from pathlib import Path
import argparse
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tool.release import release_version

HTML_TARGETS = ('web/about/index.html', 'web/terms/index.html', 'web/liability/index.html')
MARKER = re.compile(r'(<span data-app-version>)[^<]*(</span>)')


def synchronize(root=ROOT, *, write=False):
    version = release_version(root)
    generated = (
        '// Generated from pubspec.yaml by tool/version_sync.py. Do not edit by hand.\n'
        f"const appVersion = '{version}';\n"
        "const sourceRepositoryUrl = 'https://github.com/consciontologic/worthhit';\n"
    )
    updates = {root / 'lib/app/app_identity.dart': generated}
    for relative in HTML_TARGETS:
        page = root / relative
        source = page.read_text()
        updated, count = MARKER.subn(lambda m: m[1] + version + m[2], source)
        if count != 1:
            raise ValueError(f'{relative} must contain exactly one data-app-version marker.')
        updates[page] = updated
    changed = [path for path, content in updates.items()
               if not path.exists() or path.read_text() != content]
    if write:
        for path in changed:
            path.write_text(updates[path])
    return [str(path.relative_to(root)) for path in changed]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    changed = synchronize(write=args.write)
    if changed and not args.write:
        print('Version drift: ' + ', '.join(changed) + '; run make version.sync.', file=sys.stderr)
        return 1
    print('Visible release versions synchronized.' if args.write else 'Visible release versions match pubspec.yaml.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
