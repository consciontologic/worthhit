import importlib.util
from pathlib import Path
import unittest
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("release_guard", ROOT / "tool/release_guard.py")
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


def review(state="approved", user_type="User", user_id=339074048, env=42):
    return {"state": state, "user": {"type": user_type, "id": user_id},
            "environments": [{"id": env, "name": "production"}]}


class ReleaseGuardTests(unittest.TestCase):
    def test_requires_real_owner_receipt_for_correct_environment(self):
        self.assertFalse(guard.approved([], 42))
        self.assertFalse(guard.approved([review(user_type="Bot")], 42))
        self.assertFalse(guard.approved([review(user_id=7)], 42))
        self.assertFalse(guard.approved([review(env=77)], 42))
        self.assertTrue(guard.approved([review()], 42))

    def test_rejection_is_not_undone_by_later_approval(self):
        self.assertFalse(guard.approved([review("rejected"), review()], 42))

    def test_source_requires_exact_tree_success_and_current_main(self):
        base = "/repos/" + guard.REPOSITORY
        records = {
            base + "/commits/main": {"sha": "main-sha", "commit": {"tree": {"sha": "tree-a"}}},
            base + "/actions/workflows/ci.yml/runs?event=pull_request&status=success&per_page=50": {
                "workflow_runs": [{"id": 456, "event": "pull_request", "conclusion": "success",
                                   "head_repository": {"full_name": guard.REPOSITORY}, "head_sha": "tested"}]},
            base + "/actions/runs/456/jobs?per_page=100": {"jobs": [{"name": "Verify", "conclusion": "success"}, {"name": "Security", "conclusion": "success"}]},
            base + "/commits/tested": {"commit": {"tree": {"sha": "tree-a"}}},
        }
        with patch.dict(guard.os.environ, {"GITHUB_REPOSITORY": guard.REPOSITORY,
                                         "GITHUB_REF": "refs/heads/main"}), patch.object(guard, "release_request") as request:
            guard.source(api=records.__getitem__, sha="main-sha")
            request.assert_called_once_with(records.__getitem__, "main-sha", "tree-a")
            with self.assertRaisesRegex(RuntimeError, "Main changed"):
                guard.source(api=records.__getitem__, sha="old-sha")
            records[base + "/actions/runs/456/jobs?per_page=100"]["jobs"][0]["conclusion"] = "skipped"
            with self.assertRaisesRegex(RuntimeError, "No successful"):
                guard.source(api=records.__getitem__, sha="main-sha")
            records[base + "/actions/runs/456/jobs?per_page=100"]["jobs"][0]["conclusion"] = "success"
            records[base + "/commits/tested"]["commit"]["tree"]["sha"] = "different"
            with self.assertRaisesRegex(RuntimeError, "No successful"):
                guard.source(api=records.__getitem__, sha="main-sha")
            records[base + "/commits/tested"]["commit"]["tree"]["sha"] = "tree-a"
            runs = next(v for k, v in records.items() if "workflow_runs" in v)
            runs["workflow_runs"][0]["head_repository"]["full_name"] = "other/repo"
            with self.assertRaisesRegex(RuntimeError, "No successful"):
                guard.source(api=records.__getitem__, sha="main-sha")

    def test_approval_checks_environment_run_and_receipt_together(self):
        base = "/repos/" + guard.REPOSITORY
        records = {
            base + "/environments/production": {"id": 42,
                "protection_rules": [{"type": "required_reviewers", "reviewers": [
                    {"type": "User", "reviewer": {"id": guard.OWNER_ID}}]}],
                "deployment_branch_policy": {"custom_branch_policies": True}},
            base + "/environments/production/deployment-branch-policies": {
                "branch_policies": [{"name": "main", "type": "branch"}]},
            base + "/actions/runs/123": {"head_sha": "main-sha", "head_branch": "main",
                "event": "workflow_dispatch", "path": ".github/workflows/pages.yml"},
            base + "/actions/runs/123/approvals": [review()],
        }
        with patch.dict(guard.os.environ, {"GITHUB_RUN_ID": "123", "GITHUB_SHA": "main-sha"}), \
                patch.object(guard, "source") as source, patch.object(guard, "get", records.__getitem__):
            guard.approval()
            source.assert_called_once_with()
            records[base + "/actions/runs/123"]["head_sha"] = "different"
            with self.assertRaisesRegex(RuntimeError, "release source"):
                guard.approval()
            records[base + "/actions/runs/123"]["head_sha"] = "main-sha"
            records[base + "/actions/runs/123/approvals"] = []
            with self.assertRaisesRegex(RuntimeError, "human production"):
                guard.approval()
            records[base + "/actions/runs/123/approvals"] = [review()]
            records[base + "/environments/production/deployment-branch-policies"]["branch_policies"].append(
                {"name": "*", "type": "branch"})
            with self.assertRaisesRegex(RuntimeError, "only main"):
                guard.approval()

    def test_release_has_manual_human_gate_and_no_inference_secrets(self):
        workflow = (ROOT / ".github/workflows/pages.yml").read_text()
        self.assertIn("workflow_dispatch", workflow)
        self.assertIn("name: production", workflow)
        self.assertIn("release_guard.py approval", workflow)
        self.assertNotIn("OPENROUTER", workflow)
        self.assertNotIn("pull_request_target", workflow)


class VersionOnlyReleaseTests(unittest.TestCase):
    def setUp(self):
        (ROOT / '.local').mkdir(exist_ok=True)
        self.tmp = tempfile.TemporaryDirectory(dir=ROOT / '.local')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / 'pubspec.yaml').write_text('version: 1.10.0\n')
        (self.root / 'CHANGELOG.md').write_text('## [1.10.0] - 2026-10-21\n\nRelease notes.\n')
        self.sha, self.develop, self.tree = 'a' * 40, 'b' * 40, 'c' * 40
        self.base = '/repos/' + guard.REPOSITORY
        self.records = {
            self.base + '/commits/develop': {'sha': self.develop, 'commit': {'tree': {'sha': self.tree}}},
            self.base + f'/compare/{self.sha}...{self.develop}': {
                'ahead_by': 0, 'merge_base_commit': {'commit': {'tree': {'sha': self.tree}}}},
            self.base + '/releases?per_page=100&page=1': [],
        }
        environment = patch.dict(guard.os.environ, {'WORTHHIT_RELEASE_VERSION': '1.10.0'}, clear=True)
        environment.start()
        self.addCleanup(environment.stop)

    def request(self):
        return guard.release_request(self.records.__getitem__, self.sha, self.tree, self.root)

    def test_plain_version_must_match_source_and_dated_changelog(self):
        self.request()
        for invalid in ['', 'v1.10.0', '01.10.0', '1.10', '1.10.0+1', '1.10.0-rc.1', '1.10.0\n', '1.9.0']:
            guard.os.environ['WORTHHIT_RELEASE_VERSION'] = invalid
            with self.subTest(version=invalid), self.assertRaises((ValueError, RuntimeError)):
                self.request()
        guard.os.environ['WORTHHIT_RELEASE_VERSION'] = '1.10.0'
        (self.root / 'CHANGELOG.md').write_text('## [1.10.0] - Unreleased\n\nNotes.\n')
        with self.assertRaisesRegex(ValueError, 'dated'):
            self.request()

    def test_numeric_version_progression_and_same_source_recovery(self):
        releases = self.records[self.base + '/releases?per_page=100&page=1']
        releases.append({'tag_name': '1.9.0', 'target_commitish': self.develop})
        self.request()
        releases[0]['tag_name'] = '1.11.0'
        with self.assertRaisesRegex(RuntimeError, 'version'):
            self.request()
        releases[0]['tag_name'] = '1.10.0'
        with self.assertRaisesRegex(RuntimeError, 'version'):
            self.request()
        releases[0]['target_commitish'] = self.sha
        self.request()
        releases[0].update(tag_name='2.0.0', draft=True)
        self.request()

    def test_unpromoted_develop_changes_stop_release(self):
        self.records[self.base + '/commits/develop']['commit']['tree']['sha'] = 'd' * 40
        self.records[self.base + f'/compare/{self.sha}...{self.develop}']['ahead_by'] = 2
        with self.assertRaisesRegex(RuntimeError, 'develop.*promot'):
            self.request()

    def test_content_neutral_backmerge_and_behind_develop_allow_release(self):
        comparison = self.records[self.base + f'/compare/{self.sha}...{self.develop}']
        comparison['ahead_by'] = 1
        self.request()
        self.records[self.base + '/commits/develop']['commit']['tree']['sha'] = 'd' * 40
        comparison['merge_base_commit']['commit']['tree']['sha'] = 'd' * 40
        self.request()
        comparison['ahead_by'] = 0
        self.request()

    def test_incomplete_branch_and_release_metadata_fail_closed(self):
        key = self.base + f'/compare/{self.sha}...{self.develop}'
        for comparison in [{}, None, {'ahead_by': -1}, {'ahead_by': True}]:
            self.records[key] = comparison
            with self.subTest(comparison=comparison), self.assertRaises(RuntimeError):
                self.request()
        self.records[key] = {'ahead_by': 0}
        self.records[self.base + '/releases?per_page=100&page=1'] = None
        with self.assertRaisesRegex(RuntimeError, 'release'):
            self.request()

    def test_release_history_is_paginated_and_bounded(self):
        first = self.base + '/releases?per_page=100&page=1'
        self.records[first] = [{'tag_name': '1.0.0'}] * 100
        self.records[self.base + '/releases?per_page=100&page=2'] = [{'tag_name': '2.0.0'}]
        with self.assertRaisesRegex(RuntimeError, 'version'):
            self.request()
        for page in range(2, 11):
            self.records[self.base + f'/releases?per_page=100&page={page}'] = self.records[first]
        with self.assertRaisesRegex(RuntimeError, 'bound'):
            self.request()

    def test_workflow_uses_only_version_and_blank_input_cannot_publish(self):
        workflow = (ROOT / '.github/workflows/pages.yml').read_text()
        inputs = workflow.split('  workflow_dispatch:')[1].split('permissions:')[0]
        self.assertIn('      version:', inputs)
        self.assertNotIn('release_sha:', inputs)
        self.assertNotIn('release_pr:', inputs)
        self.assertIn('WORTHHIT_RELEASE_VERSION: ${{ inputs.version }}', workflow)
        self.assertIn("inputs.version != ''", workflow.split('  publish:')[1])
        self.assertIn("inputs.version != ''", workflow.split('      - uses: subosito')[0])


if __name__ == "__main__":
    unittest.main()
