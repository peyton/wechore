from __future__ import annotations

from pathlib import Path

from scripts.tooling.resolve_versions import parse_release_tag, resolve_build_number


REPO_ROOT = Path(__file__).resolve().parents[1]


def test_justfile_exposes_required_commands() -> None:
    justfile = (REPO_ROOT / "justfile").read_text(encoding="utf-8")

    for command in (
        "bootstrap:",
        "generate:",
        "build:",
        "run:",
        "test-unit:",
        "test-integration:",
        "test-ui:",
        "test-ui-ipad:",
        "test-python:",
        "lint:",
        "fmt:",
        "web-check:",
        "web-build:",
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
    assert resolve_build_number({"WECHORE_BUILD_NUMBER": "42"}) == "42"
