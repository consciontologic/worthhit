import importlib.util
from pathlib import Path
import unittest
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
                "workflow_runs": [{"event": "pull_request", "conclusion": "success",
                                   "head_repository": {"full_name": guard.REPOSITORY}, "head_sha": "tested"}]},
            base + "/commits/tested": {"commit": {"tree": {"sha": "tree-a"}}},
        }
        with patch.dict(guard.os.environ, {"GITHUB_REPOSITORY": guard.REPOSITORY,
                                         "GITHUB_REF": "refs/heads/main"}):
            guard.source(api=records.__getitem__, sha="main-sha")
            with self.assertRaisesRegex(RuntimeError, "Main changed"):
                guard.source(api=records.__getitem__, sha="old-sha")
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


if __name__ == "__main__":
    unittest.main()
