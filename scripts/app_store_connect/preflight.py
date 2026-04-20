from __future__ import annotations

import argparse
import json
import os
import plistlib
import re
import sys
from collections.abc import Mapping
from pathlib import Path
from typing import Any

from scripts.app_store_connect.check import (
    DEFAULT_BUNDLE_ID,
    load_private_key_pem,
)


REPO_ROOT = Path(__file__).resolve().parents[2]
TEAM_ID_PATTERN = re.compile(r"^[A-Z0-9]{10}$")
BUNDLE_ID_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9.-]+$")


class ReleasePreflightError(RuntimeError):
    """Raised when release metadata is invalid."""


def load_plist(path: Path) -> dict[str, Any]:
    with path.open("rb") as file:
        payload = plistlib.load(file)
    if not isinstance(payload, dict):
        raise ReleasePreflightError(f"{path} must contain a plist dictionary.")
    return payload


def load_json(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise ReleasePreflightError(f"{path} is not valid JSON: {error}") from error
    if not isinstance(payload, dict):
        raise ReleasePreflightError(f"{path} must contain a JSON object.")
    return payload


def require_env(environment: Mapping[str, str], name: str, errors: list[str]) -> str:
    value = environment.get(name, "").strip()
    if not value:
        errors.append(f"Missing required environment variable: {name}")
    return value


def validate_required_credentials(
    environment: Mapping[str, str],
    errors: list[str],
) -> None:
    require_env(environment, "APP_STORE_CONNECT_API_KEY_ID", errors)
    require_env(environment, "APP_STORE_CONNECT_API_ISSUER_ID", errors)
    if not any(
        environment.get(name)
        for name in (
            "APP_STORE_CONNECT_API_KEY_PATH",
            "APP_STORE_CONNECT_API_KEY_P8",
            "APP_STORE_CONNECT_API_KEY_P8_BASE64",
        )
    ):
        errors.append(
            "Missing App Store Connect private key. Set "
            "APP_STORE_CONNECT_API_KEY_PATH, APP_STORE_CONNECT_API_KEY_P8, "
            "or APP_STORE_CONNECT_API_KEY_P8_BASE64."
        )
        return
    try:
        load_private_key_pem(environment)
    except Exception as error:  # noqa: BLE001 - normalize release preflight failures.
        errors.append(f"App Store Connect private key could not be loaded: {error}")


def validate_release_environment(
    environment: Mapping[str, str],
    errors: list[str],
    *,
    require_credentials: bool,
) -> tuple[str, str]:
    team_id = require_env(environment, "TEAM_ID", errors)
    bundle_id = environment.get("APP_IDENTIFIER", DEFAULT_BUNDLE_ID).strip()
    cloudkit_environment = environment.get("WECHORE_CLOUD_KIT_ENVIRONMENT", "").strip()

    if team_id and TEAM_ID_PATTERN.fullmatch(team_id) is None:
        errors.append("TEAM_ID must be a 10-character Apple team identifier.")
    if not bundle_id or BUNDLE_ID_PATTERN.fullmatch(bundle_id) is None:
        errors.append(
            f"APP_IDENTIFIER must be a valid bundle id; received {bundle_id!r}."
        )
    if cloudkit_environment != "Production":
        errors.append(
            "WECHORE_CLOUD_KIT_ENVIRONMENT must be Production for TestFlight releases."
        )
    if require_credentials:
        validate_required_credentials(environment, errors)

    return team_id, bundle_id


def validate_info_plist(path: Path, errors: list[str]) -> None:
    info = load_plist(path)
    expected_values: dict[str, Any] = {
        "CFBundleShortVersionString": "$(MARKETING_VERSION)",
        "CFBundleVersion": "$(WECHORE_BUILD_NUMBER)",
        "ITSAppUsesNonExemptEncryption": False,
        "WeChoreICloudContainerIdentifier": "$(WECHORE_ICLOUD_CONTAINER)",
        "WeChoreAppGroupID": "$(WECHORE_APP_GROUP_ID)",
        "WeChoreURLScheme": "$(WECHORE_URL_SCHEME)",
    }
    for key, expected in expected_values.items():
        if info.get(key) != expected:
            errors.append(f"{path}: {key} must be {expected!r}.")

    required_usage_keys = (
        "NSContactsUsageDescription",
        "NSLocalNetworkUsageDescription",
        "NSMicrophoneUsageDescription",
        "NSSpeechRecognitionUsageDescription",
    )
    for key in required_usage_keys:
        if not str(info.get(key, "")).strip():
            errors.append(f"{path}: missing non-empty {key}.")

    url_types = info.get("CFBundleURLTypes", [])
    schemes = [
        scheme
        for entry in url_types
        if isinstance(entry, dict)
        for scheme in entry.get("CFBundleURLSchemes", [])
    ]
    if "$(WECHORE_URL_SCHEME)" not in schemes:
        errors.append(f"{path}: CFBundleURLTypes must include $(WECHORE_URL_SCHEME).")


def validate_entitlements(path: Path, errors: list[str]) -> None:
    entitlements = load_plist(path)
    expected_values: dict[str, Any] = {
        "com.apple.developer.icloud-container-environment": "$(WECHORE_ICLOUD_ENVIRONMENT)",
        "com.apple.developer.icloud-services": ["CloudKit"],
        "com.apple.developer.icloud-container-identifiers": [
            "$(WECHORE_ICLOUD_CONTAINER)"
        ],
        "com.apple.security.application-groups": ["$(WECHORE_APP_GROUP_ID)"],
    }
    for key, expected in expected_values.items():
        if entitlements.get(key) != expected:
            errors.append(f"{path}: {key} must be {expected!r}.")

    domains = entitlements.get("com.apple.developer.associated-domains", [])
    if "applinks:wechore.peyton.app" not in domains:
        errors.append(f"{path}: missing applinks:wechore.peyton.app entitlement.")


def validate_privacy_manifest(path: Path, errors: list[str]) -> None:
    privacy = load_plist(path)
    if privacy.get("NSPrivacyTracking") is not False:
        errors.append(f"{path}: NSPrivacyTracking must be false.")
    if privacy.get("NSPrivacyCollectedDataTypes") != []:
        errors.append(f"{path}: NSPrivacyCollectedDataTypes must be empty.")
    accessed_types = privacy.get("NSPrivacyAccessedAPITypes", [])
    user_defaults_reasons = [
        entry.get("NSPrivacyAccessedAPITypeReasons", [])
        for entry in accessed_types
        if entry.get("NSPrivacyAccessedAPIType")
        == "NSPrivacyAccessedAPICategoryUserDefaults"
    ]
    if not user_defaults_reasons or "CA92.1" not in user_defaults_reasons[0]:
        errors.append(f"{path}: UserDefaults access must declare reason CA92.1.")


def validate_aasa(path: Path, team_id: str, bundle_id: str, errors: list[str]) -> None:
    payload = load_json(path)
    details = payload.get("applinks", {}).get("details", [])
    expected_app_id = f"{team_id}.{bundle_id}"
    for entry in details:
        if not isinstance(entry, dict):
            continue
        if entry.get("appID") != expected_app_id:
            continue
        paths = entry.get("paths", [])
        if "/join*" in paths:
            return
    errors.append(f"{path}: missing /join* applink entry for {expected_app_id}.")


def validate_release_preflight(
    environment: Mapping[str, str] | None = None,
    repo_root: Path = REPO_ROOT,
    *,
    require_credentials: bool = False,
) -> list[str]:
    env = os.environ if environment is None else environment
    errors: list[str] = []
    team_id, bundle_id = validate_release_environment(
        env,
        errors,
        require_credentials=require_credentials,
    )
    app_root = repo_root / "app" / "WeChore"
    files = (
        app_root / "Info.plist",
        app_root / "WeChore.entitlements",
        app_root / "Resources" / "PrivacyInfo.xcprivacy",
        repo_root / "web" / ".well-known" / "apple-app-site-association",
    )
    for path in files:
        if not path.is_file():
            errors.append(f"Missing required release metadata file: {path}")

    if (app_root / "Info.plist").is_file():
        validate_info_plist(app_root / "Info.plist", errors)
    if (app_root / "WeChore.entitlements").is_file():
        validate_entitlements(app_root / "WeChore.entitlements", errors)
    if (app_root / "Resources" / "PrivacyInfo.xcprivacy").is_file():
        validate_privacy_manifest(
            app_root / "Resources" / "PrivacyInfo.xcprivacy",
            errors,
        )
    aasa = repo_root / "web" / ".well-known" / "apple-app-site-association"
    if team_id and bundle_id and aasa.is_file():
        validate_aasa(aasa, team_id, bundle_id, errors)

    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Validate local WeChore App Store release metadata."
    )
    parser.add_argument(
        "--require-credentials",
        action="store_true",
        help="Require App Store Connect API key environment variables.",
    )
    args = parser.parse_args(argv)
    try:
        errors = validate_release_preflight(
            require_credentials=args.require_credentials
        )
    except ReleasePreflightError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 2
    if errors:
        for error in errors:
            print(f"Error: {error}", file=sys.stderr)
        return 2
    print("Release metadata preflight passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
