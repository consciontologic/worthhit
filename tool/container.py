"""Build once, smoke-test, and publish the exact approved static nginx image."""
import argparse
import gzip
import http.client
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tool.release import (REPOSITORY, fingerprint, release_version, source_sha,
                          verify_bundle, verify_site, write_identity)


def run(*args, capture=False):
    return subprocess.run(list(args), check=True, text=True,
                          stdout=subprocess.PIPE if capture else None)


def image_tag():
    return 'ghcr.io/' + REPOSITORY + ':' + release_version()


def image_id(tag):
    return run('docker', 'image', 'inspect', '--format={{.Id}}', tag, capture=True).stdout.strip()


def context(site=ROOT / 'build/web', output=ROOT / 'build/container-context'):
    files = verify_site(site)
    if output.exists():
        shutil.rmtree(output)
    (output / 'site').mkdir(parents=True)
    (output / 'nginx').mkdir()
    for name in files:
        target = output / 'site' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(site / name, target)
    for name in ['nginx.conf', 'server.conf', 'headers.conf']:
        shutil.copyfile(ROOT / 'deploy/nginx' / name, output / 'nginx' / name)
    for name in ['Dockerfile', '.dockerignore']:
        shutil.copyfile(ROOT / name, output / name)
    return output


def build():
    output = ROOT / 'build/release'
    identity = verify_bundle(output, require_container=False)
    if verify_site(ROOT / 'build/web') != identity['files']:
        raise ValueError('Current web build differs from the approved release archive.')
    directory = context()
    if verify_site(directory / 'site') != identity['files']:
        raise ValueError('Container context differs from the approved release archive.')
    tag = image_tag()
    run('docker', 'build', '--pull', '--platform=linux/amd64',
        '--label=org.opencontainers.image.source=https://github.com/' + REPOSITORY,
        '--label=org.opencontainers.image.revision=' + source_sha(),
        '--label=org.opencontainers.image.version=' + identity['version'],
        '--tag=' + tag, str(directory))
    inspect = json.loads(run('docker', 'image', 'inspect', tag, capture=True).stdout)[0]
    if inspect['Os'] != 'linux' or inspect['Architecture'] != 'amd64' or inspect['Config']['User'] != '101:101':
        raise ValueError('Image platform or non-root identity differs.')
    archive = output / f'worthhit-{identity["version"]}-linux-amd64.tar.gz'
    # docker save writes only the built image, never the source checkout.
    with archive.open('wb') as raw, gzip.GzipFile(fileobj=raw, mode='wb', filename='', mtime=0) as target:
        process = subprocess.Popen(['docker', 'save', tag], stdout=subprocess.PIPE)
        try:
            shutil.copyfileobj(process.stdout, target)
        finally:
            process.stdout.close()
        if process.wait() != 0:
            raise RuntimeError('Docker could not save the release image.')
    identity['container_id'] = inspect['Id']
    identity['artifacts'][archive.name] = fingerprint(archive)
    write_identity(output, identity)
    print('Saved immutable linux/amd64 image ' + inspect['Id'])


def smoke():
    tag = image_tag()
    container = run('docker', 'run', '--detach', '--read-only', '--cap-drop=ALL',
                    '--security-opt=no-new-privileges', '--tmpfs=/tmp:rw,noexec,nosuid,size=32m',
                    '--publish=127.0.0.1::8080', tag, capture=True).stdout.strip()
    try:
        info = json.loads(run('docker', 'inspect', container, capture=True).stdout)[0]
        port = int(info['NetworkSettings']['Ports']['8080/tcp'][0]['HostPort'])
        def request(path, method='GET'):
            connection = http.client.HTTPConnection('127.0.0.1', port, timeout=3)
            try:
                connection.request(method, path)
                response = connection.getresponse()
                return response.status, dict(response.getheaders()), response.read()
            finally:
                connection.close()
        for attempt in range(20):
            try:
                if request('/healthz')[0] == 200:
                    break
            except (OSError, http.client.HTTPException):
                pass
            time.sleep(0.25)
        else:
            raise ValueError('Container did not become healthy.')
        for path, method, status in [('/', 'GET', 200), ('/', 'HEAD', 200),
            ('/about/', 'GET', 200), ('/about/index.html', 'GET', 200),
            ('/terms/', 'GET', 200), ('/terms/index.html', 'GET', 200),
            ('/liability/', 'GET', 200), ('/liability/index.html', 'GET', 200),
            ('/missing-file.js', 'GET', 404), ('/config/local.json', 'GET', 404),
            ('/.env', 'GET', 404), ('/assets/?probe=worthhit-log-sentinel', 'GET', 404), ('/', 'POST', 405), ('/', 'OPTIONS', 405)]:
            actual, headers, body = request(path, method)
            if actual != status or headers.get('X-Content-Type-Options') != 'nosniff':
                raise ValueError(f'Container HTTP contract failed for {method} {path}.')
            if path == '/' and method == 'GET' and body != (ROOT / 'build/web/index.html').read_bytes():
                raise ValueError('Container does not contain the verified public build.')
            for page in ['about', 'terms', 'liability']:
                if path.startswith('/' + page + '/') and body != (ROOT / f'build/web/{page}/index.html').read_bytes():
                    raise ValueError(f'Container {page} route does not serve the verified static page.')
            if "frame-ancestors 'none'" not in headers.get('Content-Security-Policy', ''):
                raise ValueError('Missing container security headers.')
        logs = subprocess.run(['docker', 'logs', container], check=True, text=True, capture_output=True)
        if 'worthhit-log-sentinel' in logs.stdout + logs.stderr:
            raise ValueError('Container logs exposed a request query.')
        print('Container smoke passed: non-root/read-only, GET/HEAD, true asset 404, write rejection, headers, information routes and exact HTML bytes.')
    except Exception:
        run('docker', 'logs', container)
        raise
    finally:
        run('docker', 'rm', '--force', container)


def remote_exists(tag):
    result = subprocess.run(['docker', 'manifest', 'inspect', tag], text=True, capture_output=True)
    if result.returncode == 0:
        return True
    message = result.stderr.lower()
    if 'manifest unknown' in message or 'no such manifest' in message:
        return False
    raise RuntimeError('Registry inspection failed; authentication/network errors are not an absent image.')


def registry_preflight(tag, approved_id):
    if not remote_exists(tag):
        return False
    run('docker', 'pull', '--platform=linux/amd64', tag)
    if image_id(tag) != approved_id:
        raise ValueError('Existing versioned image is immutable and differs from this artifact.')
    return True


def publish(output, apply=False):
    identity = verify_bundle(output)
    tag = image_tag()
    exists = registry_preflight(tag, identity['container_id'])
    if not apply:
        print('Container preflight passed' + ('; matching version already exists.' if exists else '.'))
        return
    from tool import release_guard
    release_guard.approval()
    if exists:
        print('Matching immutable container version already published; no push.')
        return
    archive = output / f'worthhit-{identity["version"]}-linux-amd64.tar.gz'
    run('docker', 'load', '--input=' + str(archive))
    if image_id(tag) != identity['container_id']:
        raise ValueError('Loaded image differs from the approved bundle.')
    # Recheck immediately before pushing. Never overwrite an existing version.
    if registry_preflight(tag, identity['container_id']):
        return
    run('docker', 'push', tag)
    if not registry_preflight(tag, identity['container_id']):
        raise ValueError('Published container could not be verified.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=['build', 'test', 'preflight', 'publish'])
    parser.add_argument('--directory', type=Path, default=ROOT / 'build/release')
    args = parser.parse_args()
    if args.command == 'build':
        build()
    elif args.command == 'test':
        smoke()
    else:
        publish(args.directory, apply=args.command == 'publish')
