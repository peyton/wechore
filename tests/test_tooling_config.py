from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path

import pytest

from scripts.tooling.resolve_versions import (
    VersionResolutionError,
    parse_release_tag,
    resolve_build_number,
    resolve_marketing_version,
)


REPO_ROOT = Path(__file__).resolve().parents[1]


def test_justfile_exposes_required_commands() -> None:
    justfile = (REPO_ROOT / "justfile").read_text(encoding="utf-8")

    for command in (
        "bootstrap:",
        "generate:",
        "build:",
        "run:",
        "appstore-create-app:",
        "appstore-preflight:",
        "appstore-check:",
        "testflight-archive:",
        "testflight-upload:",
        "preview-package",
        "preview-release",
        "test-unit:",
        "test-integration:",
        "test-ui:",
        "test-ui-ipad:",
        "test-python:",
        "lint:",
        "fmt:",
        "web-check:",
        "web-build:",
        "cloudflare-setup",
        "cloudflare-pages-setup:",
        "cloudflare-dns-setup:",
        "cloudflare-email-setup",
        "cloudflare-deploy",
        "cloudkit-doctor:",
        "cloudkit-export-schema:",
        "cloudkit-validate-schema:",
        "ci-build:",
        "ci:",
    ):
        assert command in justfile


def test_mise_pins_project_tools() -> None:
    mise = (REPO_ROOT / "mise.toml").read_text(encoding="utf-8")

    assert 'tuist = { version = "4.180.0", os = ["macos"] }' in mise
    assert 'just = "1.49.0"' in mise
    assert "hk =" in mise
    assert 'python = "3.14"' in mise
    assert '"npm:prettier"' in mise
    assert '"npm:wrangler"' in mise


def test_editorconfig_declares_clean_checkout_prettier_width() -> None:
    editorconfig = (REPO_ROOT / ".editorconfig").read_text(encoding="utf-8")

    assert "root = true" in editorconfig
    assert "max_line_length = 100" in editorconfig
    assert "end_of_line = lf" in editorconfig


def test_hk_config_runs_linting_steps() -> None:
    hk = (REPO_ROOT / "hk.pkl").read_text(encoding="utf-8")

    for step in (
        "markdown",
        "pkl",
        "shellcheck",
        "shfmt",
        "actionlint",
        "zizmor",
        "prettier",
        "ruff",
    ):
        assert f'["{step}"]' in hk


def test_release_tag_and_build_number_helpers() -> None:
    assert parse_release_tag("v1.2.3") == "1.2.3"
    assert resolve_marketing_version({"WECHORE_MARKETING_VERSION": "2.3.4"}) == "2.3.4"
    assert resolve_build_number({"WECHORE_BUILD_NUMBER": "42"}) == "42"
    assert (
        resolve_build_number({"GITHUB_RUN_NUMBER": "123", "GITHUB_RUN_ATTEMPT": "2"})
        == "12302"
    )
    assert resolve_build_number({}, now=datetime(2026, 4, 14, 11, 30, tzinfo=UTC)) == (
        "2604141130"
    )

    with pytest.raises(VersionResolutionError):
        resolve_marketing_version({"WECHORE_MARKETING_VERSION": "2.3"})
    with pytest.raises(VersionResolutionError):
        resolve_build_number({"WECHORE_BUILD_NUMBER": "1.2.3"})
    with pytest.raises(VersionResolutionError):
        resolve_build_number({"GITHUB_RUN_NUMBER": "abc"})
