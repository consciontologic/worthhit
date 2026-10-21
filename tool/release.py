"""Versioned, verified release bundles and immutable GitHub publication."""
import argparse
from datetime import date
import gzip
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import tarfile
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = 'consciontologic/worthhit'
SEMVER = r'(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)'


def fingerprint(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return {'bytes': path.stat().st_size, 'sha256': digest.hexdigest()}


def safe_path(name):
    if (not isinstance(name, str) or not name or '\\' in name or '\x00' in name
            or any(ord(c) < 32 for c in name) or name.startswith('/')
            or PurePosixPath(name).as_posix() != name
            or any(p in {'.', '..', '.git'} for p in name.split('/'))):
        raise ValueError('Unsafe artifact path.')
    return name


def file_at(root, name):
    safe_path(name)
    path = root
    if root.is_symlink():
        raise ValueError('Symlink root is forbidden.')
    for component in name.split('/'):
        path = path / component
        if path.is_symlink():
            raise ValueError('Symlink artifact path is forbidden.')
    return path


def release_version(root=ROOT):
    match = re.search(r'^version:\s*(\S+)\s*$', (root / 'pubspec.yaml').read_text(), re.M)
    if not match or not re.fullmatch(SEMVER, match[1]):
        raise ValueError('pubspec.yaml must contain a plain MAJOR.MINOR.PATCH version.')
    version = match[1]
    notes = (root / 'CHANGELOG.md').read_text()
    heading = re.search(r'^## \[' + re.escape(version) + r'\] - (\d{4}-\d{2}-\d{2})$', notes, re.M)
    if not heading:
        raise ValueError('The release needs a dated CHANGELOG.md entry.')
    date.fromisoformat(heading[1])
    return version


def release_notes(version, root=ROOT):
    notes = (root / 'CHANGELOG.md').read_text()
    match = re.search(r'^## \[' + re.escape(version) + r'\].*?\n(.*?)(?=^## |\Z)', notes, re.M | re.S)
    if not match or not match[1].strip():
        raise ValueError('Release notes are empty.')
    return match[1].strip()


def source_sha():
    value = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    if not re.fullmatch(r'[0-9a-f]{40}', value):
        raise ValueError('Invalid source revision.')
    if os.environ.get('GITHUB_EVENT_NAME') == 'pull_request':
        # PR jobs intentionally check out the proposed head, not GitHub's
        # synthetic merge ref. Bind that exception to the actual event payload.
        event = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text())
        pull = event.get('pull_request', {})
        if (os.environ.get('GITHUB_REPOSITORY') != REPOSITORY
                or pull.get('base', {}).get('repo', {}).get('full_name') != REPOSITORY
                or pull.get('head', {}).get('sha') != value):
            raise ValueError('Checked-out source differs from the validated PR head.')
    elif os.environ.get('GITHUB_SHA', value) != value:
        raise ValueError('Checked-out source differs from workflow source.')
    return value


def verify_site(directory):
    release = json.loads(file_at(directory, 'release.json').read_text())
    if (release.get('repository') != REPOSITORY
            or not re.fullmatch(SEMVER, release.get('app_version', ''))
            or not re.fullmatch(r'[0-9a-f]{40}', release.get('source_sha', ''))
            or not re.fullmatch(r'[0-9a-f]{64}', release.get('version', ''))):
        raise ValueError('Invalid static release identity.')
    assets = release.get('assets')
    if not isinstance(assets, dict) or 'index.html' not in assets:
        raise ValueError('Missing static manifest.')
    for name, expected in assets.items():
        path = file_at(directory, name)
        if not path.is_file() or fingerprint(path) != expected:
            raise ValueError('Static asset integrity mismatch: ' + name)
    names = set(assets) | {'release.json', 'service_worker.js'}
    for path in directory.rglob('*'):
        name = path.relative_to(directory).as_posix()
        if path.is_symlink():
            raise ValueError('Symlink artifact is forbidden.')
        if path.is_file() and name not in names:
            raise ValueError('Unlisted static file: ' + name)
    for name in names:
        if not file_at(directory, name).is_file():
            raise ValueError('Missing static artifact: ' + name)
    return {name: fingerprint(directory / name) for name in sorted(names)}


def archive_site(directory, target):
    files = verify_site(directory)
    with target.open('wb') as raw, gzip.GzipFile(fileobj=raw, mode='wb', filename='', mtime=0) as compressed:
        with tarfile.open(fileobj=compressed, mode='w|', format=tarfile.PAX_FORMAT) as archive:
            for name in files:
                data = (directory / name).read_bytes()
                info = tarfile.TarInfo(name)
                info.size, info.mode, info.mtime = len(data), 0o644, 0
                archive.addfile(info, io.BytesIO(data))
    return files


def prepare(directory=ROOT / 'build/web', output=ROOT / 'build/release'):
    version = release_version()
    sha = source_sha()
    site = json.loads((directory / 'release.json').read_text())
    if site['app_version'] != version or site['source_sha'] != sha:
        raise ValueError('Build identity differs from the source release.')
    output.mkdir(parents=True, exist_ok=True)
    # This directory contains generated release outputs only; never remove an
    # unexpected path while refreshing a local build.
    old_outputs = list(output.iterdir())
    for path in old_outputs:
        if (path.is_symlink() or not path.is_file() or not (path.name in {
                'release-identity.json', 'release-notes.md', 'SHA256SUMS'}
                or re.fullmatch(r'worthhit-' + SEMVER + r'-(?:web|linux-amd64)\.tar\.gz', path.name))):
            raise ValueError('Unexpected path in generated release directory.')
    for path in old_outputs:
        path.unlink()
    archive = output / f'worthhit-{version}-web.tar.gz'
    files = archive_site(directory, archive)
    identity = {'schema': 1, 'repository': REPOSITORY, 'version': version,
                'source_sha': sha, 'build_id': site['version'], 'files': files,
                'artifacts': {archive.name: fingerprint(archive)}}
    (output / 'release-notes.md').write_text(release_notes(version) + '\n\nSource: ' + REPOSITORY + '@' + sha + '\n')
    identity['artifacts']['release-notes.md'] = fingerprint(output / 'release-notes.md')
    write_identity(output, identity)
    print(f'Prepared Worthhit {version} from {sha}.')


def write_identity(output, identity):
    (output / 'release-identity.json').write_text(json.dumps(identity, sort_keys=True, indent=2) + '\n')
    entries = dict(identity['artifacts'])
    entries['release-identity.json'] = fingerprint(output / 'release-identity.json')
    (output / 'SHA256SUMS').write_text(''.join(f'{entry["sha256"]}  {name}\n' for name, entry in sorted(entries.items())))


def verify_bundle(output, extract=None, require_container=True):
    identity = json.loads(file_at(output, 'release-identity.json').read_text())
    if (identity.get('schema') != 1 or identity.get('repository') != REPOSITORY
            or identity.get('version') != release_version()
            or identity.get('source_sha') != source_sha()):
        raise ValueError('Bundle identity differs from the approved source.')
    version = identity['version']
    expected = {f'worthhit-{version}-web.tar.gz', 'release-notes.md'}
    container_name = f'worthhit-{version}-linux-amd64.tar.gz'
    if require_container or container_name in identity['artifacts']:
        expected.add(container_name)
        if not re.fullmatch(r'sha256:[0-9a-f]{64}', identity.get('container_id', '')):
            raise ValueError('Missing container identity.')
    if set(identity['artifacts']) != expected:
        raise ValueError('Unexpected release artifact set.')
    for name, entry in identity['artifacts'].items():
        if fingerprint(file_at(output, name)) != entry:
            raise ValueError('Release artifact integrity mismatch: ' + name)
    entries = dict(identity['artifacts'])
    entries['release-identity.json'] = fingerprint(output / 'release-identity.json')
    checksums = ''.join(f'{entry["sha256"]}  {name}\n' for name, entry in sorted(entries.items()))
    if (output / 'SHA256SUMS').read_text() != checksums:
        raise ValueError('Release checksum manifest differs.')
    if extract is not None:
        if extract.exists() and any(extract.iterdir()):
            raise ValueError('Extraction destination must be empty.')
        extract.mkdir(parents=True, exist_ok=True)
        seen = set()
        with tarfile.open(output / f'worthhit-{version}-web.tar.gz', 'r:gz') as archive:
            for item in archive:
                path = file_at(extract, item.name)
                if not item.isfile() or item.name in seen or item.name not in identity['files']:
                    raise ValueError('Unsafe archive member.')
                expected_file = identity['files'][item.name]
                if item.size != expected_file['bytes']:
                    raise ValueError('Archive size mismatch.')
                seen.add(item.name)
                path.parent.mkdir(parents=True, exist_ok=True)
                with archive.extractfile(item) as stream, path.open('wb') as target:
                    import shutil
                    shutil.copyfileobj(stream, target)
                if fingerprint(path) != expected_file:
                    raise ValueError('Archive content mismatch.')
        if seen != set(identity['files']) or verify_site(extract) != identity['files']:
            raise ValueError('Archive manifest mismatch.')
    return identity


def release_plan(version, sha, tag, existing, expected):
    if tag is not None and tag.get('object') != {'type': 'commit', 'sha': sha}:
        # GitHub adds a URL; ignore it, but never follow or move an annotated tag.
        obj = tag.get('object', {})
        if obj.get('type') != 'commit' or obj.get('sha') != sha:
            raise ValueError('Existing tag conflicts with source; tags are immutable.')
    if existing is None:
        return sorted(expected)
    if (tag is None or existing.get('tag_name') != version
            or f'Source: {REPOSITORY}@{sha}' not in existing.get('body', '')):
        raise ValueError('Existing release identity conflicts.')
    present = set()
    for asset in existing.get('assets', []):
        name = asset.get('name')
        if (name in present or name not in expected or asset.get('state') != 'uploaded'
                or asset.get('size') != expected[name]['bytes']
                or asset.get('digest') != 'sha256:' + expected[name]['sha256']):
            raise ValueError('Existing release asset differs; never replace assets.')
        present.add(name)
    missing = sorted(set(expected) - present)
    if missing and not existing.get('draft'):
        raise ValueError('Published releases cannot be extended or replaced.')
    return missing


def api(path, data=None, method='GET', optional=False, binary=None):
    host = 'https://uploads.github.com' if binary is not None else 'https://api.github.com'
    payload = binary if binary is not None else (json.dumps(data).encode() if data is not None else None)
    request = urllib.request.Request(host + path, data=payload, method=method, headers={
        'Authorization': 'Bearer ' + os.environ['GITHUB_TOKEN'],
        'Accept': 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28',
        'Content-Type': 'application/octet-stream' if binary is not None else 'application/json',
    })
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        if optional and error.code == 404:
            return None
        raise RuntimeError(f'GitHub operation failed (HTTP {error.code}); inspect the run before retrying.') from None


def find_release(base, version, request=api):
    # The tag lookup can omit a draft. Authenticated listing is also necessary
    # before creating anything, including while recovering a partial release.
    direct = request(base + '/releases/tags/' + version, optional=True)
    matches = {} if direct is None else {direct['id']: direct}
    for page in range(1, 11):
        releases = request(base + f'/releases?per_page=100&page={page}')
        if not isinstance(releases, list):
            raise ValueError('Invalid authenticated release listing.')
        for release in releases:
            if release.get('tag_name') == version:
                matches[release['id']] = release
        if len(matches) > 1:
            raise ValueError('Multiple releases share this tag; inspect instead of creating or replacing.')
        if len(releases) < 100:
            return next(iter(matches.values()), None)
    raise ValueError('Release listing exceeded its safety bound; cannot infer absence.')


def publish(output, apply=False):
    identity = verify_bundle(output)
    version, sha = identity['version'], identity['source_sha']
    base = '/repos/' + REPOSITORY
    tag = api(base + '/git/ref/tags/' + version, optional=True)
    existing = find_release(base, version, api)
    expected = {p.name: fingerprint(p) for p in output.iterdir() if p.is_file()}
    allowed = set(identity['artifacts']) | {'release-identity.json', 'SHA256SUMS'}
    if set(expected) != allowed:
        raise ValueError('Unexpected file in release bundle.')
    if existing is not None:
        existing['assets'] = api(base + f'/releases/{existing["id"]}/assets?per_page=100')
    missing = release_plan(version, sha, tag, existing, expected)
    if not apply:
        print(f'Release preflight passed; {len(missing)} immutable assets remain to upload.')
        return
    from tool import release_guard
    release_guard.approval()
    if tag is None:
        api(base + '/git/refs', {'ref': 'refs/tags/' + version, 'sha': sha}, method='POST')
    if existing is None:
        existing = api(base + '/releases', {'tag_name': version, 'target_commitish': sha,
                       'name': version, 'draft': True, 'prerelease': False,
                       'body': (output / 'release-notes.md').read_text()}, method='POST')
    for name in missing:
        result = api(base + f'/releases/{existing["id"]}/assets?name=' + urllib.parse.quote(name),
                     method='POST', binary=(output / name).read_bytes())
        if result.get('digest') != 'sha256:' + expected[name]['sha256']:
            raise ValueError('Uploaded asset digest differs; release remains a draft.')
    # Long uploads must not outlive source/develop or approval-policy changes.
    release_guard.approval()
    if existing.get('draft'):
        api(base + f'/releases/{existing["id"]}', {
            'name': version, 'draft': False, 'make_latest': 'false'}, method='PATCH')
    print(f'Immutable release {version} is published.')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=['version', 'prepare', 'verify', 'preflight', 'publish'])
    parser.add_argument('--directory', type=Path, default=ROOT / 'build/release')
    parser.add_argument('--extract', type=Path)
    args = parser.parse_args()
    if args.command == 'version':
        print(release_version())
    elif args.command == 'prepare':
        prepare(output=args.directory)
    elif args.command == 'verify':
        verify_bundle(args.directory, args.extract)
        print('Release artifact identity and checksums verified.')
    else:
        publish(args.directory, apply=args.command == 'publish')


if __name__ == '__main__':
    # Support both `python tool/release.py` and imports without a third-party package.
    import sys
    sys.path.insert(0, str(ROOT))
    main()
