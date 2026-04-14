from __future__ import annotations

import plistlib
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PROJECT_SWIFT = REPO_ROOT / "app" / "WeChore" / "Project.swift"
INFO_PLIST = REPO_ROOT / "app" / "WeChore" / "Info.plist"
ENTITLEMENTS = REPO_ROOT / "app" / "WeChore" / "WeChore.entitlements"
PRIVACY = REPO_ROOT / "app" / "WeChore" / "Resources" / "PrivacyInfo.xcprivacy"


def load_plist(path: Path) -> dict:
    with path.open("rb") as file:
        return plistlib.load(file)


def test_project_targets_ios_18_7_and_universal_ios() -> None:
    source = PROJECT_SWIFT.read_text(encoding="utf-8")

    assert 'let defaultDeploymentTarget: DeploymentTargets = .iOS("18.7")' in source
    assert "destinations: .iOS" in source
    assert '"IPHONEOS_DEPLOYMENT_TARGET"] = "18.7"' in source


def test_project_declares_prod_and_dev_flavors() -> None:
    source = PROJECT_SWIFT.read_text(encoding="utf-8")

    for expected in (
        'bundleID: "app.peyton.wechore"',
        'bundleID: "app.peyton.wechore.dev"',
        'appGroupID: "group.app.peyton.wechore"',
        'appGroupID: "group.app.peyton.wechore.dev"',
        'cloudKitContainerIdentifier: "iCloud.app.peyton.wechore"',
        'cloudKitContainerIdentifier: "iCloud.app.peyton.wechore.dev"',
        'let signingTeam = Environment.teamId.getString(default: "3VDQ4656LX")',
    ):
        assert expected in source


def test_info_plist_declares_communication_schemes_and_no_non_exempt_encryption() -> (
    None
):
    info = load_plist(INFO_PLIST)

    assert info["ITSAppUsesNonExemptEncryption"] is False
    assert set(info["LSApplicationQueriesSchemes"]) >= {"facetime-audio", "tel", "sms"}
    assert info["WeChoreICloudContainerIdentifier"] == "$(WECHORE_ICLOUD_CONTAINER)"


def test_entitlements_enable_cloudkit_and_app_groups() -> None:
    entitlements = load_plist(ENTITLEMENTS)

    assert entitlements["com.apple.developer.icloud-services"] == ["CloudKit"]
    assert entitlements["com.apple.developer.icloud-container-identifiers"] == [
        "$(WECHORE_ICLOUD_CONTAINER)"
    ]
    assert entitlements["com.apple.security.application-groups"] == [
        "$(WECHORE_APP_GROUP_ID)"
    ]


def test_privacy_manifest_disables_tracking() -> None:
    privacy = load_plist(PRIVACY)

    assert privacy["NSPrivacyTracking"] is False
    assert privacy["NSPrivacyCollectedDataTypes"] == []
