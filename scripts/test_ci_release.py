"""Release trust-boundary tests; synthetic metadata never contacts a server."""
import json
import os
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path
from ci_release import SERVICES, ROOT, create_bundle, password_ssh, validate_manifest, validate_run

class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.repo, self.commit, self.run_id = 'example/AISports', 'a' * 40, '12345'
        self.manifest = dict(schemaVersion=1, platform='linux/amd64', repository=self.repo,
                             commit=self.commit, runId=self.run_id,
                             images={s: f'ghcr.io/example/aisports-{s}@sha256:'+ 'b' * 64 for s in SERVICES})
        self.run = dict(id=12345, workflow_id=42, repository=dict(full_name=self.repo),
                        head_repository=dict(full_name=self.repo), head_branch='main', status='completed',
                        conclusion='success', event='push', head_sha=self.commit)

    def check(self, m): validate_manifest(m, self.repo, self.commit, self.run_id)
    def check_run(self, r): validate_run(r, dict(id=42), self.repo, self.run_id)
    def test_valid_manifest(self): self.check(self.manifest)
    def test_floating_tag(self):
        self.manifest['images']['backend'] = 'ghcr.io/example/aisports-backend:latest'
        with self.assertRaises(ValueError): self.check(self.manifest)
    def test_foreign_image(self):
        self.manifest['images']['backend'] = 'ghcr.io/foreign/app@sha256:' + 'b' * 64
        with self.assertRaises(ValueError): self.check(self.manifest)
    def test_missing_image(self):
        del self.manifest['images']['frontend']
        with self.assertRaises(ValueError): self.check(self.manifest)
    def test_extra_image(self):
        self.manifest['images']['extra'] = 'anything'
        with self.assertRaises(ValueError): self.check(self.manifest)
    def test_mixed_commit(self):
        self.manifest['commit'] = 'c' * 40
        with self.assertRaises(ValueError): self.check(self.manifest)
    def test_injected_run_id(self):
        with self.assertRaises(ValueError): validate_manifest(self.manifest, self.repo, self.commit, '123; execute')
    def test_valid_run(self): self.check_run(self.run)
    def test_failed_run(self):
        self.run['conclusion'] = 'failure'
        with self.assertRaises(ValueError): self.check_run(self.run)
    def test_pr_run(self):
        self.run['event'] = 'pull_request'
        with self.assertRaises(ValueError): self.check_run(self.run)
    def test_non_main(self):
        self.run['head_branch'] = 'feature'
        with self.assertRaises(ValueError): self.check_run(self.run)
    def test_fork(self):
        self.run['head_repository']['full_name'] = 'foreign/AISports'
        with self.assertRaises(ValueError): self.check_run(self.run)
    def test_other_workflow(self):
        self.run['workflow_id'] = 99
        with self.assertRaises(ValueError): self.check_run(self.run)
    def test_linux_bundle(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for folder in ('image-records', 'deploy', 'scripts'):
                (root / folder).mkdir()
            for service in SERVICES:
                image, digest = self.manifest['images'][service].split('@')
                (root / 'image-records' / f'{service}.json').write_text(json.dumps(dict(service=service, image=image, digest=digest, commit=self.commit)), encoding='utf-8')
            (root / 'deploy/compose.ecs.yml').write_bytes((ROOT / 'deploy/compose.ecs.yml').read_bytes())
            # Simulate autocrlf and prove the deployment artifact restores LF.
            (root / 'scripts/deploy-ecs.sh').write_bytes(b'#!/usr/bin/env bash\r\nset -euo pipefail\r\n')
            create_bundle(root, self.repo, self.commit, self.run_id)
            bundle = root / '.local/ci-release/bundle'
            self.assertEqual({p.name for p in bundle.iterdir()}, {'release.json', 'images.env', 'compose.ecs.yml', 'deploy-ecs.sh'})
            self.assertNotIn(b'\r', (bundle / 'deploy-ecs.sh').read_bytes())
            self.assertNotIn('.ps1', '\n'.join(p.name for p in bundle.iterdir()))
            self.assertEqual(set((bundle / 'images.env').read_text().splitlines()), {f'{name}={self.manifest["images"][s]}' for s, name in zip(SERVICES, ('BACKEND_IMAGE', 'FRONTEND_IMAGE', 'GATEWAY_IMAGE'))})

class PasswordTransportTests(unittest.TestCase):
    # Synthetic fixtures only; no real password, SSH, network or sshpass invocation.
    def test_password_in_fd_not_arguments_or_child_environment(self):
        synthetic = 'fixture # with $ spaces and quotes'
        captured = []
        def run(args, **kwargs):
            fd = int(args[2])
            captured.append(fd)
            self.assertEqual(args[:2], ['sshpass', '-d'])
            self.assertNotIn(synthetic, repr(args))
            self.assertNotIn('ECS_SSH_PASSWORD', kwargs['env'])
            self.assertNotIn('GHCR_TOKEN', kwargs['env'])
            self.assertEqual(os.read(fd, 2048), synthetic.encode() + b'\n')
            self.assertEqual(kwargs['input'], 'echo synthetic-script\n')
            self.assertEqual(kwargs['pass_fds'], (fd,))
        with patch.dict(os.environ, {'ECS_SSH_PASSWORD': synthetic, 'GHCR_TOKEN': 'synthetic-token'}, clear=True), patch('ci_release.shutil.which', return_value='/usr/bin/sshpass'), patch('ci_release.subprocess.run', side_effect=run):
            password_ssh(['ssh', 'synthetic-host'], input='echo synthetic-script\n')
        with self.assertRaises(OSError): os.fstat(captured[0])

    def test_scp_uses_same_password_pipe_without_script_stdin(self):
        def run(args, **kwargs):
            self.assertEqual(args[3], 'scp')
            self.assertIsNone(kwargs['input'])
            self.assertEqual(os.read(int(args[2]), 2048), b'synthetic-password\n')
        with patch.dict(os.environ, {'ECS_SSH_PASSWORD': 'synthetic-password'}, clear=True), patch('ci_release.shutil.which', return_value='/usr/bin/sshpass'), patch('ci_release.subprocess.run', side_effect=run):
            password_ssh(['scp', 'synthetic-file', 'synthetic-host:/opt/synthetic'])

    def test_missing_password_rejected_before_launch(self):
        with patch.dict(os.environ, {}, clear=True), patch('ci_release.shutil.which', return_value='/usr/bin/sshpass'), patch('ci_release.subprocess.run') as run:
            with self.assertRaises(ValueError): password_ssh(['ssh', 'synthetic-host'])
            run.assert_not_called()

    def test_multiline_password_rejected_before_pipe_creation(self):
        with patch.dict(os.environ, {'ECS_SSH_PASSWORD': 'synthetic\ninvalid'}, clear=True), patch('ci_release.shutil.which', return_value='/usr/bin/sshpass'), patch('ci_release.os.pipe') as pipe:
            with self.assertRaises(ValueError): password_ssh(['ssh', 'synthetic-host'])
            pipe.assert_not_called()

    def test_failure_closes_password_pipe_without_password_in_error(self):
        captured = []
        def run(args, **kwargs):
            captured.append(int(args[2]))
            raise subprocess.CalledProcessError(5, args)
        with patch.dict(os.environ, {'ECS_SSH_PASSWORD': 'synthetic-password'}, clear=True), patch('ci_release.shutil.which', return_value='/usr/bin/sshpass'), patch('ci_release.subprocess.run', side_effect=run):
            with self.assertRaises(subprocess.CalledProcessError) as failure: password_ssh(['ssh', 'synthetic-host'])
            self.assertNotIn('synthetic-password', str(failure.exception))
        with self.assertRaises(OSError): os.fstat(captured[0])

if __name__ == '__main__':
    unittest.main()
