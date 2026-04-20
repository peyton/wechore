from __future__ import annotations

import argparse
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from datetime import UTC, datetime
import json
import os
import sys
from typing import Any

from scripts.app_store_connect.check import (
    AppStoreConnectClient,
    AppStoreConnectConfig,
    AppStoreConnectError,
)


PROFILE_TYPE_APP_STORE = "IOS_APP_STORE"
DISTRIBUTION_CERTIFICATE_TYPES = frozenset({"DISTRIBUTION", "IOS_DISTRIBUTION"})


@dataclass(frozen=True)
class RequiredCapability:
    capability_type: str
    settings: tuple[Mapping[str, Any], ...] = ()


@dataclass(frozen=True)
class RequiredBundleId:
    name: str
    identifier: str
    platform: str
    capabilities: tuple[RequiredCapability, ...]
    profile_name: str


@dataclass(frozen=True)
class BundleIdRecord:
    resource_id: str
    name: str
    identifier: str
    platform: str

    @classmethod
    def from_api_resource(cls, resource: Mapping[str, Any]) -> BundleIdRecord:
        attributes = resource.get("attributes", {})
        return cls(
            resource_id=str(resource["id"]),
            name=str(attributes.get("name", "")),
            identifier=str(attributes.get("identifier", "")),
            platform=str(attributes.get("platform", "")),
        )


@dataclass(frozen=True)
class CapabilityRecord:
    resource_id: str
    capability_type: str
    settings: tuple[Mapping[str, Any], ...]

    @classmethod
    def from_api_resource(cls, resource: Mapping[str, Any]) -> CapabilityRecord:
        attributes = resource.get("attributes", {})
        settings = attributes.get("settings", [])
        if not isinstance(settings, list):
            settings = []
        return cls(
            resource_id=str(resource["id"]),
            capability_type=str(attributes.get("capabilityType", "")),
            settings=tuple(item for item in settings if isinstance(item, dict)),
        )


@dataclass(frozen=True)
class CertificateRecord:
    resource_id: str
    certificate_type: str
    display_name: str
    expiration_date: datetime | None
    activated: bool

    @classmethod
    def from_api_resource(cls, resource: Mapping[str, Any]) -> CertificateRecord:
        attributes = resource.get("attributes", {})
        return cls(
            resource_id=str(resource["id"]),
            certificate_type=str(attributes.get("certificateType", "")),
            display_name=str(
                attributes.get("displayName")
                or attributes.get("name")
                or resource["id"]
            ),
            expiration_date=parse_api_datetime(attributes.get("expirationDate")),
            activated=attributes.get("activated", True) is not False,
        )


@dataclass(frozen=True)
class ProfileRecord:
    resource_id: str
    name: str
    profile_type: str
    profile_state: str
    expiration_date: datetime | None

    @classmethod
    def from_api_resource(cls, resource: Mapping[str, Any]) -> ProfileRecord:
        attributes = resource.get("attributes", {})
        return cls(
            resource_id=str(resource["id"]),
            name=str(attributes.get("name", "")),
            profile_type=str(attributes.get("profileType", "")),
            profile_state=str(attributes.get("profileState", "")),
            expiration_date=parse_api_datetime(attributes.get("expirationDate")),
        )


@dataclass(frozen=True)
class ProvisioningAction:
    kind: str
    subject: str
    detail: str


def production_requirements() -> tuple[RequiredBundleId, ...]:
    app_group = "group.app.peyton.wechore"
    return (
        RequiredBundleId(
            name="WeChore",
            identifier="app.peyton.wechore",
            platform="IOS",
            profile_name="WeChore App Store",
            capabilities=(
                RequiredCapability(
                    "APP_GROUPS",
                    app_group_settings(app_group),
                ),
                RequiredCapability(
                    "ASSOCIATED_DOMAINS",
                ),
                RequiredCapability(
                    "ICLOUD",
                    icloud_cloudkit_settings(),
                ),
            ),
        ),
        RequiredBundleId(
            name="WeChore Widgets Extension",
            identifier="app.peyton.wechore.widgets",
            platform="IOS",
            profile_name="WeChore Widgets Extension App Store",
            capabilities=(
                RequiredCapability(
                    "APP_GROUPS",
                    app_group_settings(app_group),
                ),
            ),
        ),
    )


def app_group_settings(app_group_id: str) -> tuple[Mapping[str, Any], ...]:
    return (
        {
            "key": "APP_GROUP_IDENTIFIERS",
            "options": [{"key": app_group_id, "enabled": True}],
        },
    )


def icloud_cloudkit_settings() -> tuple[Mapping[str, Any], ...]:
    return (
        {
            "key": "ICLOUD_VERSION",
            "options": [{"key": "XCODE_6", "enabled": True}],
        },
    )


def parse_api_datetime(value: Any) -> datetime | None:
    if not isinstance(value, str) or not value:
        return None
    normalized = value.replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


def create_bundle_id_body(requirement: RequiredBundleId) -> dict[str, Any]:
    return {
        "data": {
            "type": "bundleIds",
            "attributes": {
                "identifier": requirement.identifier,
                "name": requirement.name,
                "platform": requirement.platform,
            },
        }
    }


def create_capability_body(
    bundle_id: BundleIdRecord,
    capability: RequiredCapability,
) -> dict[str, Any]:
    return {
        "data": {
            "type": "bundleIdCapabilities",
            "attributes": capability_attributes(capability),
            "relationships": {
                "bundleId": {
                    "data": {
                        "type": "bundleIds",
                        "id": bundle_id.resource_id,
                    }
                }
            },
        }
    }


def update_capability_body(
    capability_id: str,
    capability: RequiredCapability,
) -> dict[str, Any]:
    return {
        "data": {
            "type": "bundleIdCapabilities",
            "id": capability_id,
            "attributes": capability_attributes(capability),
        }
    }


def capability_attributes(capability: RequiredCapability) -> dict[str, Any]:
    attributes: dict[str, Any] = {"capabilityType": capability.capability_type}
    api_settings = capability_api_settings(capability)
    if api_settings:
        attributes["settings"] = list(api_settings)
    return attributes


def capability_api_settings(
    capability: RequiredCapability,
) -> tuple[Mapping[str, Any], ...]:
    if capability.capability_type == "APP_GROUPS":
        return ()
    return capability.settings


def create_profile_body(
    requirement: RequiredBundleId,
    bundle_id: BundleIdRecord,
    certificates: Sequence[CertificateRecord],
    profile_type: str,
    *,
    profile_name: str | None = None,
) -> dict[str, Any]:
    return {
        "data": {
            "type": "profiles",
            "attributes": {
                "name": profile_name or requirement.profile_name,
                "profileType": profile_type,
            },
            "relationships": {
                "bundleId": {
                    "data": {
                        "type": "bundleIds",
                        "id": bundle_id.resource_id,
                    }
                },
                "certificates": {
                    "data": [
                        {"type": "certificates", "id": certificate.resource_id}
                        for certificate in certificates
                    ]
                },
            },
        }
    }


def certificate_list_query() -> dict[str, str]:
    return {
        "fields[certificates]": (
            "certificateType,displayName,expirationDate,activated"
        ),
        "limit": "200",
    }


def bundle_platform_matches(actual: str, expected: str) -> bool:
    if actual == expected:
        return True
    return expected == "IOS" and actual == "UNIVERSAL"


def bundle_capabilities_query() -> dict[str, str]:
    return {"fields[bundleIdCapabilities]": "capabilityType,settings"}


def bundle_profiles_query() -> dict[str, str]:
    return {"fields[profiles]": "name,profileType,profileState,expirationDate"}


def profile_name_for_create(
    requirement: RequiredBundleId,
    profiles: Sequence[ProfileRecord],
    now: datetime,
) -> str:
    existing_names = {profile.name for profile in profiles}
    if requirement.profile_name not in existing_names:
        return requirement.profile_name

    timestamp = now.strftime("%Y%m%d%H%M%S")
    candidate = f"{requirement.profile_name} {timestamp}"
    suffix = 2
    while candidate in existing_names:
        candidate = f"{requirement.profile_name} {timestamp} {suffix}"
        suffix += 1
    return candidate


def setting_has_option(
    actual_settings: Sequence[Mapping[str, Any]],
    expected_setting: Mapping[str, Any],
) -> bool:
    expected_key = expected_setting.get("key")
    expected_options = expected_setting.get("options", [])
    if not expected_key or not isinstance(expected_options, list):
        return True

    for actual_setting in actual_settings:
        if actual_setting.get("key") != expected_key:
            continue
        actual_options = actual_setting.get("options", [])
        if not isinstance(actual_options, list):
            return False
        actual_enabled_keys = {
            str(option.get("key"))
            for option in actual_options
            if isinstance(option, dict) and option.get("enabled", True) is not False
        }
        return all(
            str(option.get("key")) in actual_enabled_keys
            for option in expected_options
            if isinstance(option, dict)
        )
    return False


def capability_satisfies(
    actual: CapabilityRecord,
    expected: RequiredCapability,
) -> bool:
    if actual.capability_type != expected.capability_type:
        return False
    return all(
        setting_has_option(actual.settings, setting)
        for setting in capability_api_settings(expected)
    )


def is_usable_distribution_certificate(
    certificate: CertificateRecord,
    now: datetime,
) -> bool:
    if certificate.certificate_type not in DISTRIBUTION_CERTIFICATE_TYPES:
        return False
    if not certificate.activated:
        return False
    return certificate.expiration_date is None or certificate.expiration_date > now


def is_usable_profile(profile: ProfileRecord, profile_type: str, now: datetime) -> bool:
    if profile.profile_type != profile_type:
        return False
    if profile.profile_state != "ACTIVE":
        return False
    return profile.expiration_date is None or profile.expiration_date > now


class ProvisioningEnsurer:
    def __init__(
        self,
        client: AppStoreConnectClient,
        *,
        dry_run: bool,
        profile_type: str,
        create_profiles: bool,
        now: datetime | None = None,
    ) -> None:
        self.client = client
        self.dry_run = dry_run
        self.profile_type = profile_type
        self.create_profiles = create_profiles
        self.now = now or datetime.now(UTC)
        self.actions: list[ProvisioningAction] = []
        self.warnings: list[str] = []

    def ensure(self, requirements: Sequence[RequiredBundleId]) -> None:
        certificates = self.distribution_certificates()
        for requirement in requirements:
            bundle_id = self.ensure_bundle_id(requirement)
            self.ensure_capabilities(bundle_id, requirement.capabilities)
            self.ensure_profile(requirement, bundle_id, certificates)

    def ensure_bundle_id(self, requirement: RequiredBundleId) -> BundleIdRecord:
        existing = self.find_bundle_id(requirement.identifier)
        if existing is not None:
            if not bundle_platform_matches(existing.platform, requirement.platform):
                raise AppStoreConnectError(
                    f"Bundle ID {requirement.identifier} has platform "
                    f"{existing.platform!r}; expected {requirement.platform!r}."
                )
            self.actions.append(
                ProvisioningAction(
                    "ok",
                    requirement.identifier,
                    f"Bundle ID exists ({existing.resource_id}).",
                )
            )
            return existing

        self.actions.append(
            ProvisioningAction(
                "create",
                requirement.identifier,
                f"Create {requirement.platform} bundle ID named {requirement.name}.",
            )
        )
        if self.dry_run:
            return BundleIdRecord(
                resource_id=f"dry-run:{requirement.identifier}",
                name=requirement.name,
                identifier=requirement.identifier,
                platform=requirement.platform,
            )
        payload = self.client.request(
            "POST",
            "/v1/bundleIds",
            body=create_bundle_id_body(requirement),
        )
        return BundleIdRecord.from_api_resource(payload["data"])

    def ensure_capabilities(
        self,
        bundle_id: BundleIdRecord,
        capabilities: Sequence[RequiredCapability],
    ) -> None:
        existing = {
            capability.capability_type: capability
            for capability in self.list_capabilities(bundle_id)
        }
        for requirement in capabilities:
            actual = existing.get(requirement.capability_type)
            if actual is None:
                self.actions.append(
                    ProvisioningAction(
                        "create",
                        bundle_id.identifier,
                        f"Enable capability {requirement.capability_type}.",
                    )
                )
                if not self.dry_run:
                    self.client.request(
                        "POST",
                        "/v1/bundleIdCapabilities",
                        body=create_capability_body(bundle_id, requirement),
                    )
                continue

            if capability_satisfies(actual, requirement):
                self.actions.append(
                    ProvisioningAction(
                        "ok",
                        bundle_id.identifier,
                        f"Capability {requirement.capability_type} is enabled.",
                    )
                )
                continue

            self.actions.append(
                ProvisioningAction(
                    "update",
                    bundle_id.identifier,
                    f"Update capability {requirement.capability_type} settings.",
                )
            )
            if not self.dry_run:
                self.client.request(
                    "PATCH",
                    f"/v1/bundleIdCapabilities/{actual.resource_id}",
                    body=update_capability_body(actual.resource_id, requirement),
                )

    def ensure_profile(
        self,
        requirement: RequiredBundleId,
        bundle_id: BundleIdRecord,
        certificates: Sequence[CertificateRecord],
    ) -> None:
        profiles = self.list_profiles(bundle_id)
        for profile in profiles:
            if is_usable_profile(profile, self.profile_type, self.now):
                self.actions.append(
                    ProvisioningAction(
                        "ok",
                        bundle_id.identifier,
                        f"{self.profile_type} provisioning profile exists: "
                        f"{profile.name} ({profile.resource_id}).",
                    )
                )
                return

        if not self.create_profiles:
            self.warnings.append(
                f"{bundle_id.identifier} has no active {self.profile_type} "
                "provisioning profile."
            )
            return

        if not certificates:
            message = (
                "No active iOS distribution certificate is available to create "
                f"{self.profile_type} provisioning profiles. Create or renew an "
                "Apple Distribution certificate, then rerun this command."
            )
            if self.dry_run:
                self.warnings.append(message)
                return
            raise AppStoreConnectError(message)

        profile_name = profile_name_for_create(requirement, profiles, self.now)
        self.actions.append(
            ProvisioningAction(
                "create",
                bundle_id.identifier,
                f"Create {self.profile_type} provisioning profile {profile_name}.",
            )
        )
        if not self.dry_run:
            self.client.request(
                "POST",
                "/v1/profiles",
                body=create_profile_body(
                    requirement,
                    bundle_id,
                    certificates,
                    self.profile_type,
                    profile_name=profile_name,
                ),
            )

    def find_bundle_id(self, identifier: str) -> BundleIdRecord | None:
        payload = self.client.request(
            "GET",
            "/v1/bundleIds",
            query={
                "filter[identifier]": identifier,
                "fields[bundleIds]": "name,identifier,platform",
                "limit": "1",
            },
        )
        resources = payload.get("data", [])
        if not resources:
            return None
        return BundleIdRecord.from_api_resource(resources[0])

    def list_capabilities(self, bundle_id: BundleIdRecord) -> list[CapabilityRecord]:
        if bundle_id.resource_id.startswith("dry-run:"):
            return []
        payload = self.client.request(
            "GET",
            f"/v1/bundleIds/{bundle_id.resource_id}/bundleIdCapabilities",
            query=bundle_capabilities_query(),
        )
        return [
            CapabilityRecord.from_api_resource(resource)
            for resource in payload.get("data", [])
        ]

    def distribution_certificates(self) -> list[CertificateRecord]:
        payload = self.client.request(
            "GET",
            "/v1/certificates",
            query=certificate_list_query(),
        )
        certificates = [
            CertificateRecord.from_api_resource(resource)
            for resource in payload.get("data", [])
        ]
        usable = [
            certificate
            for certificate in certificates
            if is_usable_distribution_certificate(certificate, self.now)
        ]
        usable.sort(
            key=lambda certificate: (
                certificate.expiration_date or datetime.max.replace(tzinfo=UTC)
            ),
            reverse=True,
        )
        if usable:
            names = ", ".join(
                f"{certificate.display_name} ({certificate.resource_id})"
                for certificate in usable
            )
            self.actions.append(
                ProvisioningAction(
                    "ok",
                    "certificates",
                    f"Active distribution certificate(s): {names}.",
                )
            )
        return usable

    def list_profiles(self, bundle_id: BundleIdRecord) -> list[ProfileRecord]:
        if bundle_id.resource_id.startswith("dry-run:"):
            return []
        payload = self.client.request(
            "GET",
            f"/v1/bundleIds/{bundle_id.resource_id}/profiles",
            query=bundle_profiles_query(),
        )
        return [
            ProfileRecord.from_api_resource(resource)
            for resource in payload.get("data", [])
        ]


def format_text_summary(
    actions: Sequence[ProvisioningAction],
    warnings: Sequence[str],
    *,
    dry_run: bool,
) -> str:
    lines = [
        "App Store Connect provisioning plan:"
        if dry_run
        else "App Store Connect provisioning result:"
    ]
    for action in actions:
        lines.append(f"- [{action.kind}] {action.subject}: {action.detail}")
    for warning in warnings:
        lines.append(f"- [warning] {warning}")
    if not actions and not warnings:
        lines.append("- No changes needed.")
    return "\n".join(lines)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Ensure WeChore production bundle IDs, capabilities, and App Store "
            "provisioning profiles exist in App Store Connect."
        )
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the required changes without creating or updating resources.",
    )
    parser.add_argument(
        "--skip-profile-create",
        action="store_true",
        help=(
            "Validate identifiers and capabilities but do not create missing "
            "provisioning profiles."
        ),
    )
    parser.add_argument(
        "--profile-type",
        default=PROFILE_TYPE_APP_STORE,
        help=f"Provisioning profile type to ensure. Default: {PROFILE_TYPE_APP_STORE}.",
    )
    parser.add_argument("--json", action="store_true", help="Print machine JSON.")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        config = AppStoreConnectConfig.from_environment(os.environ)
        ensurer = ProvisioningEnsurer(
            AppStoreConnectClient(config),
            dry_run=args.dry_run,
            profile_type=args.profile_type,
            create_profiles=not args.skip_profile_create,
        )
        ensurer.ensure(production_requirements())
    except AppStoreConnectError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 2

    if args.json:
        print(
            json.dumps(
                {
                    "dry_run": args.dry_run,
                    "actions": [action.__dict__ for action in ensurer.actions],
                    "warnings": ensurer.warnings,
                },
                sort_keys=True,
            )
        )
    else:
        print(
            format_text_summary(
                ensurer.actions,
                ensurer.warnings,
                dry_run=args.dry_run,
            )
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
