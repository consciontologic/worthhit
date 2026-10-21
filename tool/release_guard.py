"""Read-only release authorization. Never submits or bypasses approvals."""
import json
import os
from pathlib import Path
import re
import sys
import urllib.request

REPOSITORY = "consciontologic/worthhit"
OWNER_ID = 339074048


def get(path):
    request = urllib.request.Request(
        "https://api.github.com" + path,
        headers={
            "Authorization": "Bearer " + os.environ["GITHUB_TOKEN"],
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def release_request(api, sha, tree, root=Path(__file__).resolve().parents[1]):
    from tool.release import SEMVER, release_version, release_notes
    version = os.environ.get("WORTHHIT_RELEASE_VERSION", "")
    require(re.fullmatch(SEMVER, version), "Enter a plain MAJOR.MINOR.PATCH version.")
    require(version == release_version(root), "Requested version differs from pubspec.yaml.")
    release_notes(version, root)
    require(re.fullmatch(r"[0-9a-f]{40}", sha), "Release source must be an immutable commit.")
    base = "/repos/" + REPOSITORY
    develop = api(base + "/commits/develop") or {}
    develop_sha = develop.get("sha", "")
    develop_tree = develop.get("commit", {}).get("tree", {}).get("sha", "")
    require(re.fullmatch(r"[0-9a-f]{40}", develop_sha)
            and re.fullmatch(r"[0-9a-f]{40}", develop_tree), "Cannot verify develop source.")
    comparison = api(base + f"/compare/{sha}...{develop_sha}") or {}
    ahead = comparison.get("ahead_by")
    require(type(ahead) is int and ahead >= 0, "Cannot verify changes ahead on develop.")
    if ahead and develop_tree != tree:
        ancestor_tree = comparison.get("merge_base_commit", {}).get("commit", {}).get("tree", {}).get("sha")
        require(develop_tree == ancestor_tree,
                "develop has unpromoted changes; promote them through a PR before releasing.")
    # Content-neutral backmerge commits are allowed, including when main has a
    # newer hotfix and develop is unchanged since their common ancestor.
    requested = tuple(map(int, version.split('.')))
    for page in range(1, 11):
        releases = api(base + f"/releases?per_page=100&page={page}")
        require(isinstance(releases, list), "Cannot verify published release versions.")
        for item in releases:
            tag = item.get("tag_name", "")
            if item.get("draft") or item.get("prerelease") or not re.fullmatch(SEMVER, tag):
                continue
            published = tuple(map(int, tag.split('.')))
            require(requested > published or (requested == published and item.get("target_commitish") == sha),
                    "Release version must exceed published versions; only the same source may resume.")
        if len(releases) < 100:
            return
    raise RuntimeError("Published release history exceeded its safety bound.")


def source(api=get, sha=None):
    sha = sha or os.environ["GITHUB_SHA"]
    require(os.environ.get("GITHUB_REPOSITORY") == REPOSITORY, "Unexpected repository.")
    require(os.environ.get("GITHUB_REF") == "refs/heads/main", "Publication requires main.")
    base = "/repos/" + REPOSITORY
    current = api(base + "/commits/main")
    require(current["sha"] == sha, "Main changed; start a new release run.")
    tree = current["commit"]["tree"]["sha"]
    release_request(api, sha, tree)
    runs = api(base + "/actions/workflows/ci.yml/runs?event=pull_request&status=success&per_page=50")
    for run in runs.get("workflow_runs", []):
        if (run.get("event") != "pull_request" or run.get("conclusion") != "success"
                or run.get("head_repository", {}).get("full_name") != REPOSITORY):
            continue
        tested = api(base + "/commits/" + run["head_sha"])
        if tested["commit"]["tree"]["sha"] == tree:
            jobs = api(base + "/actions/runs/" + str(run["id"]) + "/jobs?per_page=100").get("jobs", [])
            checks = {job.get("name"): job.get("conclusion") for job in jobs}
            if checks.get("Verify") != "success" or checks.get("Security") != "success":
                continue
            print("Exact source tree has successful prior PR validation.")
            return
    raise RuntimeError("No successful PR validation for this exact source tree.")


def approved(reviews, environment_id):
    relevant = [review for review in reviews if any(
        env.get("id") == environment_id and env.get("name") == "production"
        for env in review.get("environments", [])
    )]
    if any(review.get("state") == "rejected" for review in relevant):
        return False
    return any(review.get("state") == "approved"
               and review.get("user", {}).get("type") == "User"
               and review.get("user", {}).get("id") == OWNER_ID for review in relevant)


def approval():
    source()
    base = "/repos/" + REPOSITORY
    environment = get(base + "/environments/production")
    reviewers = [reviewer for rule in environment.get("protection_rules", [])
                 if rule.get("type") == "required_reviewers" for reviewer in rule.get("reviewers", [])]
    require(len(reviewers) == 1 and reviewers[0].get("type") == "User"
            and reviewers[0].get("reviewer", {}).get("id") == OWNER_ID,
            "Production reviewer policy changed.")
    policy = environment.get("deployment_branch_policy", {})
    branches = get(base + "/environments/production/deployment-branch-policies").get("branch_policies", [])
    require(policy.get("custom_branch_policies") is True
            and len(branches) == 1 and branches[0].get("name") == "main"
            and branches[0].get("type") == "branch", "Production must allow only main.")
    run_id = os.environ["GITHUB_RUN_ID"]
    run = get(base + "/actions/runs/" + run_id)
    require(run.get("head_sha") == os.environ["GITHUB_SHA"]
            and run.get("head_branch") == "main"
            and run.get("event") == "workflow_dispatch"
            and run.get("path") == ".github/workflows/pages.yml",
            "Approval does not belong to this release source.")
    reviews = get(base + "/actions/runs/" + run_id + "/approvals")
    require(isinstance(reviews, list) and approved(reviews, environment["id"]),
            "No eligible human production approval receipt; bypass is not approval.")
    print("Human production approval receipt verified.")


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    try:
        {"source": source, "approval": approval}[sys.argv[1]]()
    except Exception as error:
        # Exceptions never contain token values; do not print HTTP response bodies.
        print(f"Release authorization failed: {type(error).__name__}: {error}", file=sys.stderr)
        raise SystemExit(1)
