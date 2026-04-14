from __future__ import annotations

import argparse
import base64
from collections.abc import Mapping
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
import json
import os
from pathlib import Path
import sys
from typing import Any
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, utils


API_ROOT = "https://api.appstoreconnect.apple.com"
JWT_AUDIENCE = "appstoreconnect-v1"
DEFAULT_APP_NAME = "WeChore"
DEFAULT_BUNDLE_ID = "app.peyton.wechore"
DEFAULT_SKU = "WECHORE-IOS"
DEFAULT_PRIMARY_LOCALE = "en-US"
DEFAULT_PLATFORM = "IOS"
DEFAULT_INITIAL_VERSION = "1.0.0"


class AppStoreConnectError(RuntimeError):
    """Raised when an App Store Connect API operation fails."""


class AppStoreAppMissingError(AppStoreConnectError):
    """Raised when the expected app is not visible to the API key."""


@dataclass(frozen=True)
class AppStoreConnectConfig:
    key_id: str
    issuer_id: str
    private_key_pem: bytes
    bundle_id: str = DEFAULT_BUNDLE_ID
    app_name: str = DEFAULT_APP_NAME
    sku: str = DEFAULT_SKU
    primary_locale: str = DEFAULT_PRIMARY_LOCALE
    platform: str = DEFAULT_PLATFORM
    initial_version: str = DEFAULT_INITIAL_VERSION

    @classmethod
    def from_environment(
        cls, environment: Mapping[str, str] | None = None
    ) -> AppStoreConnectConfig:
        env = environment or os.environ
        key_id = required_env(env, "APP_STORE_CONNECT_API_KEY_ID")
        issuer_id = required_env(env, "APP_STORE_CONNECT_API_ISSUER_ID")
        private_key_pem = load_private_key_pem(env)
        return cls(
            key_id=key_id,
            issuer_id=issuer_id,
            private_key_pem=private_key_pem,
            bundle_id=env.get("APP_IDENTIFIER", DEFAULT_BUNDLE_ID),
            app_name=env.get("APPSTORE_APP_NAME", DEFAULT_APP_NAME),
            sku=env.get("APPSTORE_SKU", DEFAULT_SKU),
            primary_locale=env.get("APPSTORE_PRIMARY_LOCALE", DEFAULT_PRIMARY_LOCALE),
            platform=env.get("APPSTORE_PLATFORM", DEFAULT_PLATFORM),
            initial_version=env.get(
                "APPSTORE_INITIAL_VERSION", DEFAULT_INITIAL_VERSION
            ),
        )


@dataclass(frozen=True)
class AppRecord:
    app_id: str
    name: str
    bundle_id: str
    sku: str
    primary_locale: str

    @classmethod
    def from_api_resource(cls, resource: Mapping[str, Any]) -> AppRecord:
        attributes = resource.get("attributes", {})
        return cls(
            app_id=str(resource["id"]),
            name=str(attributes.get("name", "")),
            bundle_id=str(attributes.get("bundleId", "")),
            sku=str(attributes.get("sku", "")),
            primary_locale=str(attributes.get("primaryLocale", "")),
        )


def required_env(environment: Mapping[str, str], name: str) -> str:
    value = environment.get(name)
    if not value:
        raise AppStoreConnectError(f"Missing required environment variable: {name}")
    return value


def load_private_key_pem(environment: Mapping[str, str]) -> bytes:
    key_path = environment.get("APP_STORE_CONNECT_API_KEY_PATH")
    key_base64 = environment.get("APP_STORE_CONNECT_API_KEY_P8_BASE64")
    key_raw = environment.get("APP_STORE_CONNECT_API_KEY_P8")

    if key_path:
        return Path(key_path).expanduser().read_bytes()
    if key_base64:
        return base64.b64decode(key_base64)
    if key_raw:
        return key_raw.encode("utf-8")
    raise AppStoreConnectError(
        "Missing App Store Connect private key. Set "
        "APP_STORE_CONNECT_API_KEY_PATH or APP_STORE_CONNECT_API_KEY_P8_BASE64."
    )


def base64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def create_jwt(config: AppStoreConnectConfig, now: datetime | None = None) -> str:
    issued_at = now or datetime.now(UTC)
    expires_at = issued_at + timedelta(minutes=19)
    header = {
        "alg": "ES256",
        "kid": config.key_id,
        "typ": "JWT",
    }
    payload = {
        "aud": JWT_AUDIENCE,
        "exp": int(expires_at.timestamp()),
        "iat": int(issued_at.timestamp()),
        "iss": config.issuer_id,
    }
    signing_input = (
        f"{base64url(json.dumps(header, separators=(',', ':')).encode('utf-8'))}."
        f"{base64url(json.dumps(payload, separators=(',', ':')).encode('utf-8'))}"
    ).encode("ascii")
    private_key = serialization.load_pem_private_key(
        config.private_key_pem,
        password=None,
    )
    if not isinstance(private_key, ec.EllipticCurvePrivateKey):
        raise AppStoreConnectError("App Store Connect key must be an EC private key.")
    der_signature = private_key.sign(signing_input, ec.ECDSA(hashes.SHA256()))
    r_value, s_value = utils.decode_dss_signature(der_signature)
    raw_signature = r_value.to_bytes(32, "big") + s_value.to_bytes(32, "big")
    return f"{signing_input.decode('ascii')}.{base64url(raw_signature)}"


class AppStoreConnectClient:
    def __init__(self, config: AppStoreConnectConfig) -> None:
        self.config = config

    def request(
        self,
        method: str,
        path: str,
        *,
        query: Mapping[str, str | list[str]] | None = None,
    ) -> dict[str, Any]:
        url = f"{API_ROOT}{path}"
        if query:
            url = f"{url}?{urlencode(query, doseq=True)}"
        request = Request(
            url,
            method=method,
            headers={
                "Authorization": f"Bearer {create_jwt(self.config)}",
                "Accept": "application/json",
            },
        )
        try:
            with urlopen(request, timeout=30) as response:
                return json.loads(response.read().decode("utf-8"))
        except HTTPError as error:
            body = error.read().decode("utf-8")
            try:
                payload = json.loads(body)
            except json.JSONDecodeError:
                payload = {"errors": [{"detail": body}]}
            details = "; ".join(
                str(item.get("detail") or item.get("title") or item)
                for item in payload.get("errors", [])
            )
            raise AppStoreConnectError(
                f"App Store Connect API request failed ({error.code}): {details}"
            ) from error

    def find_app(self, bundle_id: str) -> AppRecord | None:
        payload = self.request(
            "GET",
            "/v1/apps",
            query={
                "filter[bundleId]": [bundle_id],
                "fields[apps]": "name,bundleId,sku,primaryLocale",
                "limit": "1",
            },
        )
        resources = payload.get("data", [])
        if not resources:
            return None
        return AppRecord.from_api_resource(resources[0])


def manual_creation_message(config: AppStoreConnectConfig) -> str:
    return "\n".join(
        [
            f"App Store Connect app not found for bundle id {config.bundle_id}.",
            "",
            "Apple's public App Store Connect API currently exposes GET /v1/apps "
            "but no official create-app endpoint, so create this one app record "
            "in App Store Connect and rerun this check:",
            f"  Name: {config.app_name}",
            f"  Bundle ID: {config.bundle_id}",
            f"  SKU: {config.sku}",
            f"  Primary locale: {config.primary_locale}",
            f"  Platform: {config.platform}",
            f"  Version: {config.initial_version}",
            "",
            "After the app record exists, the repo can automate signing, archiving, "
            "uploading, TestFlight processing, Cloudflare Pages, DNS, and routing.",
        ]
    )


def check_app(config: AppStoreConnectConfig) -> AppRecord:
    client = AppStoreConnectClient(config)
    record = client.find_app(config.bundle_id)
    if record is None:
        raise AppStoreAppMissingError(manual_creation_message(config))
    return record


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Verify that the WeChore App Store Connect app exists."
    )
    parser.add_argument("--bundle-id", default=None, help="Expected app bundle id.")
    parser.add_argument("--json", action="store_true", help="Print machine JSON.")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        config = AppStoreConnectConfig.from_environment()
        if args.bundle_id:
            config = AppStoreConnectConfig(
                key_id=config.key_id,
                issuer_id=config.issuer_id,
                private_key_pem=config.private_key_pem,
                bundle_id=args.bundle_id,
                app_name=config.app_name,
                sku=config.sku,
                primary_locale=config.primary_locale,
                platform=config.platform,
                initial_version=config.initial_version,
            )
        record = check_app(config)
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
            "Found App Store Connect app: "
            f"{record.name} ({record.bundle_id}, sku {record.sku}, id {record.app_id})"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
