from __future__ import annotations

import argparse
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
import json
import os
import sys
from typing import Any
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


API_ROOT = "https://api.cloudflare.com/client/v4"
DEFAULT_ZONE_NAME = "peyton.app"
DEFAULT_PROJECT_NAME = "wechore"
DEFAULT_DOMAIN = "wechore.peyton.app"
DEFAULT_PRODUCTION_BRANCH = "master"
DEFAULT_EMAIL_PREFIXES = ("support", "privacy", "security", "contact")


class CloudflareSetupError(RuntimeError):
    """Raised when Cloudflare setup cannot complete."""


@dataclass(frozen=True)
class CloudflareConfig:
    api_token: str
    account_id: str | None = None
    zone_id: str | None = None
    zone_name: str = DEFAULT_ZONE_NAME
    project_name: str = DEFAULT_PROJECT_NAME
    domain: str = DEFAULT_DOMAIN
    email_domain: str = DEFAULT_DOMAIN
    production_branch: str = DEFAULT_PRODUCTION_BRANCH
    destination_email: str | None = None
    email_prefixes: tuple[str, ...] = DEFAULT_EMAIL_PREFIXES

    @classmethod
    def from_environment(
        cls,
        environment: Mapping[str, str] | None = None,
        *,
        destination_email: str | None = None,
        skip_email: bool = False,
    ) -> CloudflareConfig:
        env = environment or os.environ
        token = env.get("CLOUDFLARE_API_TOKEN")
        if not token:
            raise CloudflareSetupError("Missing CLOUDFLARE_API_TOKEN.")
        configured_destination = (
            None
            if skip_email
            else (destination_email or env.get("EMAIL_ROUTING_DESTINATION"))
        )
        prefixes = env.get("EMAIL_ROUTING_PREFIXES")
        return cls(
            api_token=token,
            account_id=env.get("CLOUDFLARE_ACCOUNT_ID"),
            zone_id=env.get("CLOUDFLARE_ZONE_ID"),
            zone_name=env.get("CLOUDFLARE_ZONE_NAME", DEFAULT_ZONE_NAME),
            project_name=env.get("CLOUDFLARE_PAGES_PROJECT", DEFAULT_PROJECT_NAME),
            domain=env.get("WECHORE_WEB_DOMAIN", DEFAULT_DOMAIN),
            email_domain=env.get("WECHORE_EMAIL_DOMAIN", DEFAULT_DOMAIN),
            production_branch=env.get(
                "CLOUDFLARE_PAGES_PRODUCTION_BRANCH",
                DEFAULT_PRODUCTION_BRANCH,
            ),
            destination_email=configured_destination,
            email_prefixes=tuple(
                item.strip()
                for item in (
                    prefixes.split(",") if prefixes else DEFAULT_EMAIL_PREFIXES
                )
                if item.strip()
            ),
        )


class CloudflareClient:
    def __init__(self, api_token: str) -> None:
        self.api_token = api_token

    def request(
        self,
        method: str,
        path: str,
        *,
        query: Mapping[str, str | int | bool] | None = None,
        body: Mapping[str, Any] | None = None,
        allow_not_found: bool = False,
    ) -> dict[str, Any] | None:
        url = f"{API_ROOT}{path}"
        if query:
            url = f"{url}?{urlencode(query)}"
        data = None
        headers = {
            "Accept": "application/json",
            "Authorization": f"Bearer {self.api_token}",
        }
        if body is not None:
            data = json.dumps(body).encode("utf-8")
            headers["Content-Type"] = "application/json"
        request = Request(url, data=data, method=method, headers=headers)
        try:
            with urlopen(request, timeout=30) as response:
                payload = json.loads(response.read().decode("utf-8"))
        except HTTPError as error:
            payload = parse_error_payload(error)
            if allow_not_found and error.code == 404:
                return None
            raise CloudflareSetupError(
                format_cloudflare_error(error.code, payload)
            ) from error

        if not payload.get("success", False):
            raise CloudflareSetupError(format_cloudflare_error(None, payload))
        return payload


def parse_error_payload(error: HTTPError) -> dict[str, Any]:
    body = error.read().decode("utf-8")
    try:
        return json.loads(body)
    except json.JSONDecodeError:
        return {"errors": [{"message": body}]}


def format_cloudflare_error(status: int | None, payload: Mapping[str, Any]) -> str:
    prefix = (
        f"Cloudflare API request failed ({status})"
        if status
        else ("Cloudflare API request failed")
    )
    messages = "; ".join(
        str(item.get("message") or item) for item in payload.get("errors", [])
    )
    return f"{prefix}: {messages or payload}"


def ensure_zone_and_account(
    client: CloudflareClient, config: CloudflareConfig
) -> tuple[str, str]:
    if config.zone_id and config.account_id:
        return config.zone_id, config.account_id

    payload = client.request(
        "GET",
        "/zones",
        query={"name": config.zone_name, "per_page": 1},
    )
    zones = payload.get("result", []) if payload else []
    if not zones:
        raise CloudflareSetupError(f"Cloudflare zone not found: {config.zone_name}")
    zone = zones[0]
    zone_id = config.zone_id or str(zone["id"])
    account_id = config.account_id or str(zone["account"]["id"])
    return zone_id, account_id


def ensure_pages_project(
    client: CloudflareClient,
    account_id: str,
    config: CloudflareConfig,
) -> dict[str, Any]:
    path = f"/accounts/{account_id}/pages/projects/{config.project_name}"
    existing = client.request("GET", path, allow_not_found=True)
    if existing is None:
        payload = client.request(
            "POST",
            f"/accounts/{account_id}/pages/projects",
            body={
                "name": config.project_name,
                "production_branch": config.production_branch,
                "build_config": {
                    "build_command": "mise exec -- just web-build",
                    "destination_dir": ".build/web",
                    "root_dir": "",
                },
            },
        )
        return payload["result"] if payload else {}

    project = existing["result"]
    if project.get("production_branch") != config.production_branch:
        payload = client.request(
            "PATCH",
            path,
            body={"production_branch": config.production_branch},
        )
        return payload["result"] if payload else project
    return project


def ensure_pages_domain(
    client: CloudflareClient,
    account_id: str,
    config: CloudflareConfig,
) -> dict[str, Any]:
    path = f"/accounts/{account_id}/pages/projects/{config.project_name}/domains"
    payload = client.request("GET", path)
    domains = payload.get("result", []) if payload else []
    for domain in domains:
        if domain.get("name") == config.domain:
            return domain
    created = client.request("POST", path, body={"name": config.domain})
    return created["result"] if created else {}


def ensure_dns_cname(
    client: CloudflareClient,
    zone_id: str,
    config: CloudflareConfig,
) -> dict[str, Any]:
    content = f"{config.project_name}.pages.dev"
    payload = client.request(
        "GET",
        f"/zones/{zone_id}/dns_records",
        query={"type": "CNAME", "name": config.domain, "per_page": 1},
    )
    records = payload.get("result", []) if payload else []
    body = {
        "type": "CNAME",
        "name": config.domain,
        "content": content,
        "ttl": 1,
        "proxied": True,
        "comment": "WeChore Cloudflare Pages production custom domain",
    }
    if records:
        record = records[0]
        if record.get("content") == content and record.get("proxied") is True:
            return record
        updated = client.request(
            "PUT",
            f"/zones/{zone_id}/dns_records/{record['id']}",
            body=body,
        )
        return updated["result"] if updated else record
    created = client.request("POST", f"/zones/{zone_id}/dns_records", body=body)
    return created["result"] if created else {}


def route_addresses(config: CloudflareConfig) -> tuple[str, ...]:
    return tuple(f"{prefix}@{config.email_domain}" for prefix in config.email_prefixes)


def validate_email_domain(config: CloudflareConfig) -> None:
    if config.email_domain == config.domain:
        raise CloudflareSetupError(
            "Cannot route email for addresses at "
            f"{config.email_domain} while Cloudflare Pages uses the same hostname. "
            "Pages custom domains require a CNAME record and email delivery requires "
            "MX records at that hostname; DNS does not allow CNAME and MX records "
            "to coexist. Set WECHORE_EMAIL_DOMAIN to a different domain, for example "
            "peyton.app, or move the website to a different hostname."
        )


def routing_rule_payload(
    address: str, destination_email: str, priority: int
) -> dict[str, Any]:
    return {
        "actions": [{"type": "forward", "value": [destination_email]}],
        "enabled": True,
        "matchers": [{"field": "to", "type": "literal", "value": address}],
        "name": f"Forward {address}",
        "priority": priority,
    }


def ensure_destination_address(
    client: CloudflareClient,
    account_id: str,
    destination_email: str,
) -> dict[str, Any]:
    payload = client.request(
        "GET",
        f"/accounts/{account_id}/email/routing/addresses",
        query={"per_page": 100},
    )
    addresses = payload.get("result", []) if payload else []
    for address in addresses:
        if address.get("email") == destination_email:
            return address
    created = client.request(
        "POST",
        f"/accounts/{account_id}/email/routing/addresses",
        body={"email": destination_email},
    )
    return created["result"] if created else {}


def ensure_email_routing_dns(client: CloudflareClient, zone_id: str) -> None:
    client.request("POST", f"/zones/{zone_id}/email/routing/dns")
    client.request("POST", f"/zones/{zone_id}/email/routing/enable")


def rule_matches_address(rule: Mapping[str, Any], address: str) -> bool:
    for matcher in rule.get("matchers", []):
        if matcher.get("field") == "to" and matcher.get("value") == address:
            return True
    return False


def ensure_routing_rules(
    client: CloudflareClient,
    zone_id: str,
    addresses: Sequence[str],
    destination_email: str,
) -> list[dict[str, Any]]:
    payload = client.request(
        "GET",
        f"/zones/{zone_id}/email/routing/rules",
        query={"per_page": 100},
    )
    rules = payload.get("result", []) if payload else []
    ensured: list[dict[str, Any]] = []
    for index, address in enumerate(addresses, start=10):
        body = routing_rule_payload(address, destination_email, index)
        existing = next(
            (rule for rule in rules if rule_matches_address(rule, address)), None
        )
        if existing:
            updated = client.request(
                "PUT",
                f"/zones/{zone_id}/email/routing/rules/{existing['id']}",
                body=body,
            )
            ensured.append(updated["result"] if updated else existing)
        else:
            created = client.request(
                "POST",
                f"/zones/{zone_id}/email/routing/rules",
                body=body,
            )
            ensured.append(created["result"] if created else body)
    return ensured


def setup_cloudflare(
    config: CloudflareConfig,
    *,
    include_pages: bool = True,
    include_dns: bool = True,
    include_email: bool = True,
) -> dict[str, Any]:
    client = CloudflareClient(config.api_token)
    zone_id, account_id = ensure_zone_and_account(client, config)
    result: dict[str, Any] = {
        "account_id": account_id,
        "zone_id": zone_id,
        "zone_name": config.zone_name,
    }

    if include_pages:
        result["pages_project"] = ensure_pages_project(client, account_id, config)
        result["pages_domain"] = ensure_pages_domain(client, account_id, config)
    if include_dns:
        result["dns_record"] = ensure_dns_cname(client, zone_id, config)
    if include_email:
        if not config.destination_email:
            result["email_routing"] = {
                "skipped": True,
                "reason": "EMAIL_ROUTING_DESTINATION was not provided.",
            }
        else:
            validate_email_domain(config)
            destination = ensure_destination_address(
                client, account_id, config.destination_email
            )
            ensure_email_routing_dns(client, zone_id)
            addresses = route_addresses(config)
            rules = ensure_routing_rules(
                client,
                zone_id,
                addresses,
                config.destination_email,
            )
            result["email_routing"] = {
                "destination": destination,
                "addresses": addresses,
                "rules": rules,
            }
    return result


def print_text_summary(result: Mapping[str, Any]) -> None:
    print(f"Cloudflare account: {result['account_id']}")
    print(f"Cloudflare zone: {result['zone_name']} ({result['zone_id']})")
    if "pages_project" in result:
        project = result["pages_project"]
        print(f"Pages project: {project.get('name')} ({project.get('subdomain')})")
    if "pages_domain" in result:
        domain = result["pages_domain"]
        print(f"Pages domain: {domain.get('name')} ({domain.get('status')})")
    if "dns_record" in result:
        record = result["dns_record"]
        print(f"DNS CNAME: {record.get('name')} -> {record.get('content')}")
    if "email_routing" in result:
        email = result["email_routing"]
        if email.get("skipped"):
            print(f"Email routing skipped: {email['reason']}")
        else:
            addresses = ", ".join(email["addresses"])
            print(f"Email routing: {addresses}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Set up Cloudflare Pages, DNS, and Email Routing for WeChore."
    )
    parser.add_argument(
        "--destination-email",
        default=None,
        help="Verified mailbox that receives routed WeChore email.",
    )
    parser.add_argument("--skip-pages", action="store_true", help="Skip Pages setup.")
    parser.add_argument("--skip-dns", action="store_true", help="Skip DNS setup.")
    parser.add_argument("--skip-email", action="store_true", help="Skip Email Routing.")
    parser.add_argument("--json", action="store_true", help="Print machine JSON.")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        config = CloudflareConfig.from_environment(
            destination_email=args.destination_email,
            skip_email=args.skip_email,
        )
        result = setup_cloudflare(
            config,
            include_pages=not args.skip_pages,
            include_dns=not args.skip_dns,
            include_email=not args.skip_email,
        )
    except CloudflareSetupError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 2

    if args.json:
        print(json.dumps(result, sort_keys=True))
    else:
        print_text_summary(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
