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
        "appstore-check-asc:",
        "appstore-provisioning-plan:",
        "appstore-ensure-provisioning:",
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


def test_appstore_check_uses_python_api_client_by_default() -> None:
    justfile = (REPO_ROOT / "justfile").read_text(encoding="utf-8")

    assert (
        "appstore-check:\n"
        "    WECHORE_FLAVOR=prod mise exec -- uv run python -m "
        "scripts.app_store_connect.check"
    ) in justfile
    assert "appstore-check-asc:" in justfile


def test_mise_pins_project_tools() -> None:
    mise = (REPO_ROOT / "mise.toml").read_text(encoding="utf-8")

    assert 'tuist = { version = "4.180.0", os = ["macos"] }' in mise
    assert 'just = "1.49.0"' in mise
    assert "hk =" in mise
    assert 'python = "3.14"' in mise
    assert '"npm:prettier"' in mise
    assert '"npm:wrangler"' in mise
    assert '"github:rudrankriyam/App-Store-Connect-CLI"' in mise


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


def test_ios_test_wrapper_retries_simulator_launch_timeouts() -> None:
    script = (REPO_ROOT / "scripts" / "tooling" / "test_ios.sh").read_text(
        encoding="utf-8"
    )

    assert "Timed out while launching application via Xcode" in script
    assert "Failed to send signal 19" in script
    assert "if has_xctest_failure && ! is_simulator_launch_error; then" in script
    assert (
        'if [ "$attempt" -ge "$max_attempts" ] || ! is_simulator_launch_error; then'
        in (script)
    )


def test_release_scripts_do_not_require_helper_execute_bits() -> None:
    for script_name in ("archive_release.sh", "upload_testflight.sh"):
        script = (REPO_ROOT / "scripts" / "tooling" / script_name).read_text(
            encoding="utf-8"
        )

        assert 'api_key_path="$(bash "$TOOLING_DIR/appstore_api_key.sh")"' in script

    upload_script = (
        REPO_ROOT / "scripts" / "tooling" / "upload_testflight.sh"
    ).read_text(encoding="utf-8")
    assert 'bash "$TOOLING_DIR/archive_release.sh" --archive-path "$archive_path"' in (
        upload_script
    )


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
