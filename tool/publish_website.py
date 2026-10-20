"""Ownership-safe GitOps publication of an already verified static release."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import shlex
import re

ROOT = Path(__file__).resolve().parents[1]
import sys
sys.path.insert(0, str(ROOT))
from tool.release import REPOSITORY, file_at, fingerprint, safe_path, verify_site

MANIFEST = '.worthhit-deploy.json'
DESTINATION = 'git@github.com:consciontologic/worthhit.com.git'


def prepare(site, destination):
    files = verify_site(site)
    release = json.loads((site / 'release.json').read_text())
    content = {name: (site / name).read_bytes() for name in files}
    content['CNAME'] = b'worthhit.com\n'
    content['.nojekyll'] = b''
    manifest_path = file_at(destination, MANIFEST)
    prior = {}
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text())
        if manifest.get('schema') != 1 or manifest.get('repository') != REPOSITORY:
            raise ValueError('Foreign or invalid destination ownership manifest.')
        prior = manifest.get('files')
        if not isinstance(prior, dict) or MANIFEST in prior:
            raise ValueError('Invalid ownership file list.')
    # Plan and validate every path before a single write or removal.
    for name, expected in prior.items():
        path = file_at(destination, name)
        if not path.is_file() or fingerprint(path) != expected:
            raise ValueError('A managed destination file was edited or removed: ' + name)
    for name in content:
        path = file_at(destination, name)
        if path.exists() and name not in prior:
            raise ValueError('Unowned destination file collision: ' + name)
        if path.exists() and not path.is_file():
            raise ValueError('Destination file path is not a regular file.')
        parent = path.parent
        while parent != destination:
            if parent.exists() and not parent.is_dir():
                raise ValueError('Destination parent is not a directory.')
            parent = parent.parent
    import hashlib
    owned = {name: {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
             for name, data in sorted(content.items())}
    content[MANIFEST] = (json.dumps({'schema': 1, 'repository': REPOSITORY,
        'source_sha': release['source_sha'], 'version': release['app_version'],
        'files': owned}, sort_keys=True, indent=2) + '\n').encode()
    changed = []
    for name in sorted(set(prior) - set(content)):
        file_at(destination, name).unlink()
        changed.append(name)
    for name, data in content.items():
        path = file_at(destination, name)
        if path.exists() and path.read_bytes() == data:
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        changed.append(name)
    return sorted(changed)


def publish(site):
    from tool import release_guard
    if (os.environ.get('GITHUB_ACTIONS') != 'true'
            or os.environ.get('GITHUB_EVENT_NAME') != 'workflow_dispatch'):
        raise ValueError('Website publication requires the approved release workflow.')
    if not os.environ.get('WORTHHIT_DEPLOY_KEY'):
        raise ValueError('Missing production WORTHHIT_DEPLOY_KEY for the website repository.')
    release_guard.approval()
    destination = release_guard.get('/repos/consciontologic/worthhit.com')
    if (destination.get('full_name') != 'consciontologic/worthhit.com'
            or destination.get('owner', {}).get('id') != release_guard.OWNER_ID):
        raise ValueError('Website destination ownership changed.')
    host_keys = release_guard.get('/meta').get('ssh_keys', [])
    if not host_keys or not all(isinstance(key, str) and re.fullmatch(
            r'(?:ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256) [A-Za-z0-9+/=]+', key) for key in host_keys):
        raise ValueError('GitHub HTTPS metadata did not supply valid SSH host keys.')
    release = json.loads((site / 'release.json').read_text())
    if release['source_sha'] != os.environ['GITHUB_SHA']:
        raise ValueError('Website source differs from the approved run.')
    with tempfile.TemporaryDirectory(prefix='worthhit-website-', dir=os.environ['RUNNER_TEMP']) as temp:
        root = Path(temp)
        key = root / 'deploy-key'
        key.write_text(os.environ['WORTHHIT_DEPLOY_KEY'].rstrip() + '\n')
        key.chmod(0o600)
        known_hosts = root / 'known_hosts'
        known_hosts.write_text(''.join('github.com ' + host_key + '\n' for host_key in host_keys))
        ssh = ['ssh', '-F', '/dev/null', '-i', str(key), '-o', 'IdentitiesOnly=yes',
               '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15',
               '-o', 'StrictHostKeyChecking=yes', '-o', 'UserKnownHostsFile=' + str(known_hosts)]
        env = dict(os.environ, GIT_SSH_COMMAND=shlex.join(ssh), GIT_TERMINAL_PROMPT='0',
                   GIT_CONFIG_COUNT='1', GIT_CONFIG_KEY_0='credential.helper', GIT_CONFIG_VALUE_0='')
        checkout = root / 'checkout'
        subprocess.run(['git', 'clone', '--no-checkout', DESTINATION, str(checkout)], env=env, check=True)
        def git(*args, capture=False):
            return subprocess.run(['git', '-C', str(checkout), *args], env=env, check=True,
                                  text=True, stdout=subprocess.PIPE if capture else None)
        refs = git('for-each-ref', '--format=%(refname)', 'refs/remotes/origin/', capture=True).stdout.splitlines()
        if not refs:
            git('checkout', '--orphan', 'main')
        elif 'refs/remotes/origin/main' in refs:
            git('checkout', '-B', 'main', 'origin/main')
        else:
            raise ValueError('Destination has commits without main; do not guess its deployment branch.')
        changed = prepare(site, checkout)
        if not changed:
            print('Website already matches the approved release.')
            return
        paths = root / 'managed-paths'
        paths.write_bytes(b''.join(name.encode() + b'\0' for name in changed))
        git('add', '--all', '--force', '--pathspec-from-file=' + str(paths), '--pathspec-file-nul')
        # Do not roll back a later source that arrived during preparation.
        release_guard.source()
        git('-c', 'user.name=github-actions[bot]', '-c',
            'user.email=41898282+github-actions[bot]@users.noreply.github.com', 'commit',
            '-m', f'deploy(web): publish {REPOSITORY}@{release["source_sha"]}')
        git('push', 'origin', 'HEAD:main')
        print('Published only managed static files to consciontologic/worthhit.com.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('site', type=Path)
    publish(parser.parse_args().site)
