from __future__ import annotations

import base64
from pathlib import Path

import pytest

from scripts.app_store_connect.check import (
    AppRecord,
    AppStoreAppMissingError,
    AppStoreConnectConfig,
    AppStoreConnectError,
    DEFAULT_BUNDLE_ID,
    manual_creation_message,
    validate_app_record,
)
from scripts.app_store_connect.check_asc import (
    app_record_from_asc_payload,
    asc_environment,
)
from scripts.app_store_connect.preflight import validate_release_preflight
from scripts.cloudflare.setup import (
    CloudflareConfig,
    DEFAULT_EMAIL_PREFIXES,
    CloudflareSetupError,
    route_addresses,
    routing_rule_payload,
    validate_email_domain,
)


def test_app_store_manual_creation_message_names_required_values() -> None:
    config = AppStoreConnectConfig(
        key_id="KEY123",
        issuer_id="issuer",
        private_key_pem=b"key",
    )

    message = manual_creation_message(config)

    assert "no official create-app endpoint" in message
    assert "Name: WeChore" in message
    assert f"Bundle ID: {DEFAULT_BUNDLE_ID}" in message
    assert "SKU: WECHORE-IOS" in message
    assert "Version: 1.0.0" in message


def test_cloudflare_route_addresses_use_wechore_subdomain() -> None:
    config = CloudflareConfig(api_token="token")

    assert route_addresses(config) == tuple(
        f"{prefix}@wechore.peyton.app" for prefix in DEFAULT_EMAIL_PREFIXES
    )


def test_cloudflare_route_addresses_can_use_separate_email_domain() -> None:
    config = CloudflareConfig(api_token="token", email_domain="peyton.app")

    assert route_addresses(config) == tuple(
        f"{prefix}@peyton.app" for prefix in DEFAULT_EMAIL_PREFIXES
    )


def test_cloudflare_rejects_pages_cname_email_mx_conflict() -> None:
    config = CloudflareConfig(api_token="token")

    with pytest.raises(CloudflareSetupError, match="CNAME and MX"):
        validate_email_domain(config)


def test_cloudflare_routing_rule_payload_forwards_literal_address() -> None:
    payload = routing_rule_payload(
        "support@wechore.peyton.app",
        "owner@example.com",
        10,
    )

    assert payload["enabled"] is True
    assert payload["matchers"] == [
        {
            "field": "to",
            "type": "literal",
            "value": "support@wechore.peyton.app",
        }
    ]
    assert payload["actions"] == [{"type": "forward", "value": ["owner@example.com"]}]
    assert payload["priority"] == 10


def test_private_key_can_be_loaded_from_base64_env(tmp_path: Path) -> None:
    from scripts.app_store_connect.check import load_private_key_pem

    key = b"-----BEGIN PRIVATE KEY-----\nexample\n-----END PRIVATE KEY-----\n"

    assert (
        load_private_key_pem(
            {
                "APP_STORE_CONNECT_API_KEY_P8_BASE64": base64.b64encode(key).decode(
                    "ascii"
                )
            }
        )
        == key
    )

    key_path = tmp_path / "AuthKey_KEY123.p8"
    key_path.write_bytes(key)
    assert (
        load_private_key_pem({"APP_STORE_CONNECT_API_KEY_PATH": str(key_path)}) == key
    )


def test_private_key_rejects_invalid_base64_env() -> None:
    from scripts.app_store_connect.check import load_private_key_pem

    with pytest.raises(AppStoreConnectError, match="not valid base64"):
        load_private_key_pem({"APP_STORE_CONNECT_API_KEY_P8_BASE64": "not base64!"})


def test_app_store_record_metadata_must_match_expected_values() -> None:
    config = AppStoreConnectConfig(
        key_id="KEY123",
        issuer_id="issuer",
        private_key_pem=b"key",
    )
    record = AppRecord(
        app_id="app-id",
        name="Wrong",
        bundle_id=DEFAULT_BUNDLE_ID,
        sku="WRONG-SKU",
        primary_locale="en-US",
    )

    with pytest.raises(AppStoreConnectError, match="metadata mismatch"):
        validate_app_record(config, record)


def test_asc_environment_maps_existing_app_store_connect_names() -> None:
    env = asc_environment(
        {
            "APP_STORE_CONNECT_API_KEY_ID": "KEY123",
            "APP_STORE_CONNECT_API_ISSUER_ID": "issuer",
            "APP_STORE_CONNECT_API_KEY_P8_BASE64": "base64",
        }
    )

    assert env["ASC_KEY_ID"] == "KEY123"
    assert env["ASC_ISSUER_ID"] == "issuer"
    assert env["ASC_PRIVATE_KEY_B64"] == "base64"
    assert env["ASC_BYPASS_KEYCHAIN"] == "1"


def test_asc_app_check_reuses_manual_creation_message() -> None:
    config = AppStoreConnectConfig(
        key_id="KEY123",
        issuer_id="issuer",
        private_key_pem=b"key",
    )

    with pytest.raises(AppStoreAppMissingError, match="Name: WeChore"):
        app_record_from_asc_payload({"data": []}, config)


def test_release_preflight_accepts_committed_app_store_metadata() -> None:
    key = b"-----BEGIN PRIVATE KEY-----\nexample\n-----END PRIVATE KEY-----\n"

    errors = validate_release_preflight(
        {
            "APP_IDENTIFIER": DEFAULT_BUNDLE_ID,
            "APP_STORE_CONNECT_API_KEY_ID": "KEY123",
            "APP_STORE_CONNECT_API_ISSUER_ID": "issuer",
            "APP_STORE_CONNECT_API_KEY_P8_BASE64": base64.b64encode(key).decode(
                "ascii"
            ),
            "TEAM_ID": "3VDQ4656LX",
            "WECHORE_CLOUD_KIT_ENVIRONMENT": "Production",
        },
        require_credentials=True,
    )

    assert errors == []


def test_release_preflight_rejects_development_cloudkit_environment() -> None:
    errors = validate_release_preflight(
        {
            "APP_IDENTIFIER": DEFAULT_BUNDLE_ID,
            "TEAM_ID": "3VDQ4656LX",
            "WECHORE_CLOUD_KIT_ENVIRONMENT": "Development",
        },
        require_credentials=False,
    )

    assert any("must be Production" in error for error in errors)
