from __future__ import annotations

import base64
from datetime import UTC, datetime, timedelta
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
from scripts.app_store_connect.provisioning import (
    BundleIdRecord,
    CapabilityRecord,
    CertificateRecord,
    ProfileRecord,
    RequiredCapability,
    app_group_settings,
    capability_satisfies,
    create_bundle_id_body,
    create_capability_body,
    create_profile_body,
    is_usable_distribution_certificate,
    is_usable_profile,
    production_requirements,
)
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
    encoded_key = base64.b64encode(key).decode("ascii")

    assert (
        load_private_key_pem({"APP_STORE_CONNECT_API_KEY_P8_BASE64": encoded_key})
        == key
    )
    assert (
        load_private_key_pem(
            {
                "APP_STORE_CONNECT_API_KEY_P8_BASE64": (
                    f"{encoded_key[:16]}\n{encoded_key[16:32]}\n{encoded_key[32:]}"
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


def test_provisioning_requirements_cover_app_and_widget_identifiers() -> None:
    requirements = production_requirements()

    assert [requirement.identifier for requirement in requirements] == [
        DEFAULT_BUNDLE_ID,
        "app.peyton.wechore.widgets",
    ]
    assert {cap.capability_type for cap in requirements[0].capabilities} == {
        "APP_GROUPS",
        "ASSOCIATED_DOMAINS",
        "ICLOUD",
    }
    assert {cap.capability_type for cap in requirements[1].capabilities} == {
        "APP_GROUPS"
    }


def test_create_bundle_id_body_uses_json_api_shape() -> None:
    requirement = production_requirements()[0]

    body = create_bundle_id_body(requirement)

    assert body == {
        "data": {
            "type": "bundleIds",
            "attributes": {
                "identifier": DEFAULT_BUNDLE_ID,
                "name": "WeChore",
                "platform": "IOS",
            },
        }
    }


def test_create_capability_body_links_capability_to_bundle_id() -> None:
    bundle = BundleIdRecord(
        resource_id="bundle-123",
        name="WeChore",
        identifier=DEFAULT_BUNDLE_ID,
        platform="IOS",
    )
    capability = RequiredCapability(
        "APP_GROUPS",
        app_group_settings("group.app.peyton.wechore"),
    )

    body = create_capability_body(bundle, capability)

    assert body["data"]["type"] == "bundleIdCapabilities"
    assert body["data"]["attributes"] == {
        "capabilityType": "APP_GROUPS",
        "settings": [
            {
                "key": "APP_GROUP_IDENTIFIERS",
                "options": [{"key": "group.app.peyton.wechore", "enabled": True}],
            }
        ],
    }
    assert body["data"]["relationships"]["bundleId"]["data"] == {
        "type": "bundleIds",
        "id": "bundle-123",
    }


def test_create_profile_body_links_bundle_and_certificates() -> None:
    requirement = production_requirements()[0]
    bundle = BundleIdRecord(
        resource_id="bundle-123",
        name="WeChore",
        identifier=DEFAULT_BUNDLE_ID,
        platform="IOS",
    )
    certificates = [
        CertificateRecord(
            resource_id="cert-1",
            certificate_type="DISTRIBUTION",
            display_name="Apple Distribution",
            expiration_date=None,
            activated=True,
        )
    ]

    body = create_profile_body(requirement, bundle, certificates, "IOS_APP_STORE")

    assert body["data"]["type"] == "profiles"
    assert body["data"]["attributes"] == {
        "name": "WeChore App Store",
        "profileType": "IOS_APP_STORE",
    }
    assert body["data"]["relationships"]["bundleId"]["data"]["id"] == "bundle-123"
    assert body["data"]["relationships"]["certificates"]["data"] == [
        {"type": "certificates", "id": "cert-1"}
    ]


def test_capability_satisfies_required_enabled_options() -> None:
    expected = RequiredCapability(
        "APP_GROUPS",
        app_group_settings("group.app.peyton.wechore"),
    )
    actual = CapabilityRecord(
        resource_id="cap-1",
        capability_type="APP_GROUPS",
        settings=(
            {
                "key": "APP_GROUP_IDENTIFIERS",
                "options": [{"key": "group.app.peyton.wechore", "enabled": True}],
            },
        ),
    )
    disabled = CapabilityRecord(
        resource_id="cap-1",
        capability_type="APP_GROUPS",
        settings=(
            {
                "key": "APP_GROUP_IDENTIFIERS",
                "options": [{"key": "group.app.peyton.wechore", "enabled": False}],
            },
        ),
    )

    assert capability_satisfies(actual, expected)
    assert not capability_satisfies(disabled, expected)


def test_distribution_certificate_and_profile_usability_checks_expiration() -> None:
    now = datetime(2026, 4, 14, tzinfo=UTC)
    active_certificate = CertificateRecord(
        resource_id="cert-1",
        certificate_type="IOS_DISTRIBUTION",
        display_name="Apple Distribution",
        expiration_date=now + timedelta(days=1),
        activated=True,
    )
    expired_profile = ProfileRecord(
        resource_id="profile-1",
        name="WeChore App Store",
        profile_type="IOS_APP_STORE",
        profile_state="ACTIVE",
        expiration_date=now - timedelta(days=1),
    )

    assert is_usable_distribution_certificate(active_certificate, now)
    assert not is_usable_profile(expired_profile, "IOS_APP_STORE", now)
