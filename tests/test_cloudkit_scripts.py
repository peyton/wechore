from __future__ import annotations

from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def test_cloudkit_scripts_use_wechore_container_defaults() -> None:
    env_file = (REPO_ROOT / "scripts" / "tooling" / "wechore.env").read_text(
        encoding="utf-8"
    )
    doctor = (REPO_ROOT / "scripts" / "cloudkit" / "doctor.sh").read_text(
        encoding="utf-8"
    )
    export = (REPO_ROOT / "scripts" / "cloudkit" / "export-schema.sh").read_text(
        encoding="utf-8"
    )

    assert "iCloud.app.peyton.wechore" in env_file
    assert "CLOUDKIT_TEAM_ID" in doctor
    assert "export-schema" in export
    assert "--container-id" in export


def test_tooling_env_declares_iphone_and_ipad_simulators() -> None:
    env_file = (REPO_ROOT / "scripts" / "tooling" / "wechore.env").read_text(
        encoding="utf-8"
    )

    assert "DEFAULT_IPHONE_DEVICE" in env_file
    assert "DEFAULT_IPAD_DEVICE" in env_file
    assert "TEST_IPHONE_SIMULATOR_NAME" in env_file
    assert "TEST_IPAD_SIMULATOR_NAME" in env_file
