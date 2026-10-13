"""CI release metadata and SSH transport. Python runs on CI; ECS needs no Python."""
from __future__ import annotations
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

SERVICES = ('backend', 'frontend', 'ai-gateway')
ROOT = Path(__file__).resolve().parents[1]

def required(name):
    value = os.environ.get(name, '')
    if not value:
        raise ValueError(f'Missing setting: {name}')
    return value

def identity(repository, commit, run_id):
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository) or not re.fullmatch(r'[a-f0-9]{40}', commit) or not re.fullmatch(r'[1-9][0-9]*', str(run_id)):
        raise ValueError('Invalid release identity')

def validate_manifest(manifest, repository, commit, run_id):
    identity(repository, commit, run_id)
    expected = dict(schemaVersion=1, platform='linux/amd64', repository=repository, commit=commit)
    if any(manifest.get(k) != v for k, v in expected.items()) or str(manifest.get('runId')) != str(run_id):
        raise ValueError('Release manifest does not match the approved build')
    images = manifest.get('images')
    if not isinstance(images, dict) or set(images) != set(SERVICES):
        raise ValueError('A release must contain exactly three images')
    for service in SERVICES:
        prefix = f'ghcr.io/{repository.lower()}-{service}@'
        value = images[service]
        if not isinstance(value, str) or not value.startswith(prefix) or not re.fullmatch(r'sha256:[a-f0-9]{64}', value[len(prefix):]):
            raise ValueError(f'Unexpected or unpinned image: {service}')

def validate_run(run, workflow, repository, run_id):
    if (not re.fullmatch(r'[1-9][0-9]*', str(run_id)) or str(run.get('id')) != str(run_id)
        or run.get('workflow_id') != workflow.get('id')
        or run.get('repository', {}).get('full_name') != repository
        or (run.get('head_repository') or {}).get('full_name') != repository
        or run.get('head_branch') != 'main' or run.get('status') != 'completed'
        or run.get('conclusion') != 'success' or run.get('event') not in ('push', 'workflow_dispatch')
        or not re.fullmatch(r'[a-f0-9]{40}', run.get('head_sha', ''))):
        raise ValueError('Choose a successful main-branch CI image build from this repository')

def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')

def output(name, value):
    with Path(required('GITHUB_OUTPUT')).open('a', encoding='utf-8') as stream:
        stream.write(f'{name}={value}\n')

def record_image():
    service, repo, commit, digest = (required(k) for k in ('SERVICE', 'REPOSITORY', 'COMMIT', 'DIGEST'))
    if service not in SERVICES or not re.fullmatch(r'sha256:[a-f0-9]{64}', digest):
        raise ValueError('Missing pushed digest or invalid service')
    identity(repo, commit, '1')
    image = f'ghcr.io/{repo.lower()}-{service}'
    write_json(ROOT / 'image-records' / f'{service}.json', dict(service=service, image=image, digest=digest, commit=commit))

def create_bundle(root, repository, commit, run_id):
    images = {}
    for service in SERVICES:
        record = json.loads((root / 'image-records' / f'{service}.json').read_text(encoding='utf-8-sig'))
        if record.get('service') != service or record.get('commit') != commit:
            raise ValueError('An image came from a different build')
        images[service] = record['image'] + '@' + record['digest']
    manifest = dict(schemaVersion=1, repository=repository, commit=commit, runId=str(run_id), platform='linux/amd64', images=images)
    validate_manifest(manifest, repository, commit, run_id)
    bundle = root / '.local/ci-release/bundle'
    bundle.mkdir(parents=True, exist_ok=False)
    write_json(bundle / 'release.json', manifest)
    write_images(bundle, manifest)
    shutil.copyfile(root / 'deploy/compose.ecs.yml', bundle / 'compose.ecs.yml')
    # Normalize Linux script bytes even when a contributor has Windows autocrlf.
    script = (root / 'scripts/deploy-ecs.sh').read_text(encoding='utf-8')
    (bundle / 'deploy-ecs.sh').write_text(script, encoding='utf-8', newline='\n')
    print('Three tested image digests sealed; four non-secret release files')

def write_images(bundle, manifest):
    names = dict(backend='BACKEND_IMAGE', frontend='FRONTEND_IMAGE', **{'ai-gateway': 'GATEWAY_IMAGE'})
    (bundle / 'images.env').write_text(''.join(f'{names[s]}={manifest["images"][s]}\n' for s in SERVICES), encoding='utf-8', newline='\n')

def check_source_run():
    repository, run_id = required('RELEASE_REPOSITORY'), required('BUILD_RUN_ID')
    identity(repository, 'a' * 40, run_id)
    headers = {'Authorization': 'Bearer ' + required('GH_TOKEN'), 'Accept': 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28'}
    base = f'https://api.github.com/repos/{repository}/actions'
    def get(path):
        request = urllib.request.Request(base + path, headers=headers)
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    workflow = get('/workflows/ci-images.yml')
    run = get('/runs/' + run_id)
    validate_run(run, workflow, repository, run_id)
    output('commit', run['head_sha'])
    print('Source CI run succeeded on main')

def password_ssh(args, *, input=None):
    """Supply sshpass an inherited pipe; never put a password in argv or a file.

    stdin remains available for the remote Bash script. Credentials are stripped
    from the SSH/SCP child environment; only the dedicated fd carries the password.
    """
    if shutil.which('sshpass') is None:
        raise ValueError('Install sshpass on the CI runner before deployment')
    password = required('ECS_SSH_PASSWORD')
    if any(c in password for c in ('\n', '\r', '\x00')) or len(password.encode('utf-8')) > 1024:
        raise ValueError('Unsupported SSH password format')
    read_fd, write_fd = os.pipe()
    try:
        os.write(write_fd, password.encode('utf-8') + b'\n')
        os.close(write_fd)
        write_fd = None
        child_env = {k: v for k, v in os.environ.items() if k not in
                     ('ECS_SSH_PASSWORD', 'GHCR_TOKEN', 'GH_TOKEN', 'ECS_KNOWN_HOSTS')}
        subprocess.run(['sshpass', '-d', str(read_fd), *args], input=input, text=True,
                       pass_fds=(read_fd,), env=child_env, check=True)
    finally:
        os.close(read_fd)
        if write_fd is not None:
            os.close(write_fd)

def deploy():
    repository, commit, run_id = (required(k) for k in ('RELEASE_REPOSITORY', 'RELEASE_COMMIT', 'RELEASE_RUN_ID'))
    bundle = ROOT / '.local/ecs-release'
    manifest = json.loads((bundle / 'release.json').read_text(encoding='utf-8-sig'))
    validate_manifest(manifest, repository, commit, run_id)
    # Recompute this transport file from the validated manifest, never source it.
    write_images(bundle, manifest)
    host, user, port, root = (required(k) for k in ('ECS_HOST', 'ECS_USER', 'ECS_SSH_PORT', 'ECS_DEPLOY_ROOT'))
    if (not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.-]*', host)
        or not re.fullmatch(r'[a-z_][a-z0-9_-]{0,31}', user)
        or not port.isdecimal() or not 1 <= int(port) <= 65535
        or not re.fullmatch(r'/(opt|srv)/[A-Za-z0-9/_-]+', root)):
        raise ValueError('Invalid ECS connection settings')
    root = root.rstrip('/')
    release = f'{root}/releases/{commit}-{run_id}'
    remote_host = f'{user}@{host}'
    with tempfile.TemporaryDirectory(prefix='aisports-ssh-', dir=required('RUNNER_TEMP')) as temp:
        temp = Path(temp)
        hosts, token = (temp / n for n in ('known_hosts', 'registry-token'))
        hosts.write_text(required('ECS_KNOWN_HOSTS').replace('\r', '').strip() + '\n', encoding='utf-8')
        token.write_text(required('GHCR_TOKEN') + '\n', encoding='utf-8')
        for path in (hosts, token):
            path.chmod(0o600)
        opts = ['-o', 'BatchMode=no', '-o', 'PreferredAuthentications=password,keyboard-interactive',
                '-o', 'PubkeyAuthentication=no', '-o', 'NumberOfPasswordPrompts=1',
                '-o', 'StrictHostKeyChecking=yes', '-o', f'UserKnownHostsFile={hosts}', '-o', 'ConnectTimeout=20']
        def remote(script, args):
            command = shlex.join(['bash', '-s', '--', *args])
            password_ssh(['ssh', *opts, '-p', port, remote_host, command], input=script)
        transferred = False
        try:
            remote('set -euo pipefail\numask 077\ntest -f "$1/config/server.env"\nmkdir -p -- "$2"\nchmod 700 -- "$2"\n', [root, release])
            for name in ('release.json', 'images.env', 'compose.ecs.yml', 'deploy-ecs.sh'):
                password_ssh(['scp', *opts, '-P', port, str(bundle / name), f'{remote_host}:{release}/{name}'])
            password_ssh(['scp', *opts, '-P', port, str(token), f'{remote_host}:{release}/registry-token'])
            transferred = True
            command = shlex.join(['bash', release + '/deploy-ecs.sh', root, commit, run_id, repository, required('GHCR_USER')])
            password_ssh(['ssh', *opts, '-p', port, remote_host, command])
            with Path(required('GITHUB_STEP_SUMMARY')).open('a', encoding='utf-8') as stream:
                stream.write(f'已部署提交 `{commit}`，构建运行 `{run_id}`。数据服务独立保留。\n')
        finally:
            if transferred:
                try:
                    remote('set -euo pipefail\nrm -f -- "$1/registry-token"\n', [release])
                except subprocess.CalledProcessError:
                    print('Remote staging cleanup could not be confirmed; the task token expires automatically', file=sys.stderr)

def main():
    command = sys.argv[1]
    if command == 'image-name':
        repository, service = required('REPOSITORY'), required('SERVICE')
        identity(repository, 'a' * 40, '1')
        if service not in SERVICES:
            raise ValueError('Unexpected service')
        output('name', f'ghcr.io/{repository.lower()}-{service}')
    elif command == 'record-image':
        record_image()
    elif command == 'bundle':
        create_bundle(ROOT, *(required(k) for k in ('RELEASE_REPOSITORY', 'RELEASE_COMMIT', 'RELEASE_RUN_ID')))
    elif command == 'source-run':
        check_source_run()
    elif command == 'deploy':
        deploy()
    elif command == 'summary':
        with Path(required('GITHUB_STEP_SUMMARY')).open('a', encoding='utf-8') as stream:
            stream.write(f'三个镜像已推送GHCR。手动部署时选择构建运行ID `{required("RELEASE_RUN_ID")}`，提交 `{required("RELEASE_COMMIT")}`；清单保留14天。\n')
    else:
        raise ValueError('Unsupported release command')

if __name__ == '__main__':
    main()
