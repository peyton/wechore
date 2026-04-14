from __future__ import annotations

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
