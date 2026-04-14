from __future__ import annotations

import json
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def test_ci_workflow_uses_mise_and_just_shards() -> None:
    workflow = (REPO_ROOT / ".github" / "workflows" / "ci.yml").read_text(
        encoding="utf-8"
    )

    assert "jdx/mise-action@1648a7812b9aeae629881980618f079932869151" in workflow
    assert "mise exec -- just ci-lint" in workflow
    assert "mise exec -- just ci-python" in workflow
    assert "mise exec -- just test-unit" in workflow
    assert "mise exec -- just test-integration" in workflow
    assert "mise exec -- just test-ui" in workflow
    assert "mise exec -- just test-ui-ipad" in workflow
    assert "mise exec -- just ci-build" in workflow


def test_release_web_workflow_packages_wechore_site() -> None:
    workflow = (REPO_ROOT / ".github" / "workflows" / "release-web.yml").read_text(
        encoding="utf-8"
    )

    assert '"web/v*.*.*"' in workflow
    assert "scripts.web.package_static_site" in workflow
    assert "wechore-web-${{ env.WEB_VERSION }}.tar.gz" in workflow


def test_preview_release_workflow_uses_non_semver_prerelease_tags() -> None:
    workflow = (REPO_ROOT / ".github" / "workflows" / "preview-release.yml").read_text(
        encoding="utf-8"
    )

    assert "branches: [master]" in workflow
    assert 'preview_version="master-${GITHUB_RUN_NUMBER}-${short_sha}"' in workflow
    assert "PREVIEW_TAG=preview/$preview_version" in workflow
    assert "mise exec -- just preview-package" in workflow
    assert "--prerelease" in workflow
    assert "--latest=false" in workflow


def test_testflight_workflow_uploads_from_master_with_environment_secrets() -> None:
    workflow = (REPO_ROOT / ".github" / "workflows" / "testflight.yml").read_text(
        encoding="utf-8"
    )

    assert "branches: [master]" in workflow
    assert "environment: testflight" in workflow
    assert "APP_STORE_CONNECT_API_KEY_ID" in workflow
    assert "APP_STORE_CONNECT_API_ISSUER_ID" in workflow
    assert "APP_STORE_CONNECT_API_KEY_P8_BASE64" in workflow
    assert "mise exec -- just appstore-check" in workflow
    assert "mise exec -- just testflight-upload" in workflow


def test_deploy_web_workflow_separates_production_and_preview() -> None:
    workflow = (REPO_ROOT / ".github" / "workflows" / "deploy-web.yml").read_text(
        encoding="utf-8"
    )

    assert "branches: [master]" in workflow
    assert "environment: web-production" in workflow
    assert "environment: web-preview" in workflow
    assert "mise exec -- just cloudflare-deploy BRANCH=master" in workflow
    assert (
        "mise exec -- just cloudflare-deploy BRANCH=pr-${{ github.event.number }}"
        in (workflow)
    )
    assert "github.event.pull_request.head.repo.full_name == github.repository" in (
        workflow
    )


def test_renovate_low_risk_updates_are_gated_by_required_checks() -> None:
    renovate = json.loads((REPO_ROOT / "renovate.json").read_text(encoding="utf-8"))

    assert renovate["timezone"] == "America/Los_Angeles"
    assert renovate["schedule"] == ["before 7am on monday"]
    assert renovate["platformAutomerge"] is True
    assert renovate["github-actions"]["pinDigests"] is True

    low_risk_rule = renovate["packageRules"][0]
    assert low_risk_rule["matchUpdateTypes"] == [
        "minor",
        "patch",
        "digest",
        "pinDigest",
    ]
    assert low_risk_rule["automerge"] is True

    major_rule = renovate["packageRules"][1]
    assert major_rule["matchUpdateTypes"] == ["major"]
    assert major_rule["automerge"] is False


def test_dependabot_security_auto_merge_is_narrowly_gated() -> None:
    dependabot = (REPO_ROOT / ".github" / "dependabot.yml").read_text(encoding="utf-8")
    workflow = (
        REPO_ROOT / ".github" / "workflows" / "dependabot-auto-merge.yml"
    ).read_text(encoding="utf-8")
    zizmor = (REPO_ROOT / ".github" / "zizmor.yml").read_text(encoding="utf-8")

    assert 'package-ecosystem: "uv"' in dependabot
    assert 'package-ecosystem: "github-actions"' in dependabot
    assert dependabot.count("open-pull-requests-limit: 0") == 2
    assert "pull_request_target:" in workflow
    assert "github.event.pull_request.user.login == 'dependabot[bot]'" in workflow
    assert (
        "github.event.pull_request.head.repo.full_name == github.repository" in workflow
    )
    assert "actions/checkout" not in workflow
    assert "version-update:semver-patch" in workflow
    assert "version-update:semver-minor" in workflow
    assert "--auto --squash" in workflow
    assert "dependabot-auto-merge.yml" in zizmor


def test_contributing_docs_name_repo_local_validation_commands() -> None:
    contributing = (REPO_ROOT / "CONTRIBUTING.md").read_text(encoding="utf-8")

    assert "just bootstrap" in contributing
    assert "just generate" in contributing
    assert "mise exec -- just lint" in contributing
    assert "mise exec -- just ci" in contributing
