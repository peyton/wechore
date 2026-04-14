from __future__ import annotations

import argparse
from collections.abc import Mapping
import json
import os
import subprocess
import sys
from typing import Any

from scripts.app_store_connect.check import (
    AppRecord,
    AppStoreAppMissingError,
    AppStoreConnectConfig,
    AppStoreConnectError,
    DEFAULT_APP_NAME,
    DEFAULT_BUNDLE_ID,
    DEFAULT_INITIAL_VERSION,
    DEFAULT_PLATFORM,
    DEFAULT_PRIMARY_LOCALE,
    DEFAULT_SKU,
    manual_creation_message,
    validate_app_record,
)


def expected_config(environment: Mapping[str, str]) -> AppStoreConnectConfig:
    return AppStoreConnectConfig(
        key_id=environment.get("APP_STORE_CONNECT_API_KEY_ID", ""),
        issuer_id=environment.get("APP_STORE_CONNECT_API_ISSUER_ID", ""),
        private_key_pem=b"",
        bundle_id=environment.get("APP_IDENTIFIER", DEFAULT_BUNDLE_ID),
        app_name=environment.get("APPSTORE_APP_NAME", DEFAULT_APP_NAME),
        sku=environment.get("APPSTORE_SKU", DEFAULT_SKU),
        primary_locale=environment.get(
            "APPSTORE_PRIMARY_LOCALE", DEFAULT_PRIMARY_LOCALE
        ),
        platform=environment.get("APPSTORE_PLATFORM", DEFAULT_PLATFORM),
        initial_version=environment.get(
            "APPSTORE_INITIAL_VERSION", DEFAULT_INITIAL_VERSION
        ),
    )


def asc_environment(environment: Mapping[str, str]) -> dict[str, str]:
    asc_env = dict(environment)
    mappings = {
        "APP_STORE_CONNECT_API_KEY_ID": "ASC_KEY_ID",
        "APP_STORE_CONNECT_API_ISSUER_ID": "ASC_ISSUER_ID",
        "APP_STORE_CONNECT_API_KEY_PATH": "ASC_PRIVATE_KEY_PATH",
        "APP_STORE_CONNECT_API_KEY_P8": "ASC_PRIVATE_KEY",
        "APP_STORE_CONNECT_API_KEY_P8_BASE64": "ASC_PRIVATE_KEY_B64",
    }
    for source, target in mappings.items():
        value = asc_env.get(source)
        if value and not asc_env.get(target):
            asc_env[target] = value

    has_env_key = bool(
        asc_env.get("ASC_KEY_ID")
        and asc_env.get("ASC_ISSUER_ID")
        and (
            asc_env.get("ASC_PRIVATE_KEY")
            or asc_env.get("ASC_PRIVATE_KEY_B64")
            or asc_env.get("ASC_PRIVATE_KEY_PATH")
        )
    )
    if has_env_key and "ASC_BYPASS_KEYCHAIN" not in asc_env:
        asc_env["ASC_BYPASS_KEYCHAIN"] = "1"
    return asc_env


def app_record_from_asc_payload(
    payload: Mapping[str, Any],
    config: AppStoreConnectConfig,
) -> AppRecord:
    resources = payload.get("data", [])
    if not isinstance(resources, list):
        raise AppStoreConnectError("asc apps list returned malformed JSON: data")
    if not resources:
        raise AppStoreAppMissingError(manual_creation_message(config))
    return AppRecord.from_api_resource(resources[0])


def verify_payload(
    payload: Mapping[str, Any],
    config: AppStoreConnectConfig,
) -> AppRecord:
    record = app_record_from_asc_payload(payload, config)
    validate_app_record(config, record)
    return record


def run_asc_apps_list(
    config: AppStoreConnectConfig, environment: Mapping[str, str]
) -> dict[str, Any]:
    command = [
        "asc",
        "--strict-auth",
        "apps",
        "list",
        "--bundle-id",
        config.bundle_id,
        "--output",
        "json",
    ]
    result = subprocess.run(
        command,
        check=False,
        env=asc_environment(environment),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise AppStoreConnectError(f"asc apps list failed: {detail}")
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise AppStoreConnectError("asc apps list did not return JSON.") from error
    if not isinstance(payload, dict):
        raise AppStoreConnectError("asc apps list returned malformed JSON.")
    return payload


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Verify that the WeChore App Store Connect app exists using asc."
    )
    parser.add_argument("--bundle-id", default=None, help="Expected app bundle id.")
    parser.add_argument("--json", action="store_true", help="Print machine JSON.")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    config = expected_config(os.environ)
    if args.bundle_id:
        config = AppStoreConnectConfig(
            key_id=config.key_id,
            issuer_id=config.issuer_id,
            private_key_pem=b"",
            bundle_id=args.bundle_id,
            app_name=config.app_name,
            sku=config.sku,
            primary_locale=config.primary_locale,
            platform=config.platform,
            initial_version=config.initial_version,
        )

    try:
        payload = run_asc_apps_list(config, os.environ)
        record = verify_payload(payload, config)
    except AppStoreAppMissingError as error:
        print(str(error), file=sys.stderr)
        return 3
    except AppStoreConnectError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 2

    if args.json:
        print(json.dumps(record.__dict__, sort_keys=True))
    else:
        print(
            "Found App Store Connect app with asc: "
            f"{record.name} ({record.bundle_id}, sku {record.sku}, id {record.app_id})"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
