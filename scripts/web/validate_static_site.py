from __future__ import annotations

import argparse
import json
from dataclasses import dataclass, field
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlparse

CONTACT_EMAIL = "contact@wechore.peyton.app"
SUPPORT_EMAIL = "support@wechore.peyton.app"
PRIVACY_EMAIL = "privacy@wechore.peyton.app"
SECURITY_EMAIL = "security@wechore.peyton.app"
REQUIRED_FILES = (
    "index.html",
    "support/index.html",
    "privacy/index.html",
    "license/index.html",
    "404.html",
    "robots.txt",
    "sitemap.xml",
    "assets/app-icon.svg",
    "assets/app-preview.svg",
    "assets/site.css",
    ".well-known/apple-app-site-association",
)
REQUIRED_EMAILS_BY_FILE = {
    Path("index.html"): (CONTACT_EMAIL, SUPPORT_EMAIL, PRIVACY_EMAIL, SECURITY_EMAIL),
    Path("support/index.html"): (
        CONTACT_EMAIL,
        SUPPORT_EMAIL,
        PRIVACY_EMAIL,
        SECURITY_EMAIL,
    ),
    Path("privacy/index.html"): (
        CONTACT_EMAIL,
        SUPPORT_EMAIL,
        PRIVACY_EMAIL,
        SECURITY_EMAIL,
    ),
    Path("license/index.html"): (CONTACT_EMAIL,),
    Path("404.html"): (CONTACT_EMAIL, SUPPORT_EMAIL),
}
REQUIRED_LICENSE_LINK_FILES = (
    Path("index.html"),
    Path("support/index.html"),
    Path("privacy/index.html"),
    Path("license/index.html"),
)
REQUIRED_LICENSE_PHRASES = (
    "source-available for review only",
    "not open source",
    "all rights reserved",
    "no license is granted",
    "app marketplace",
    "derivative works",
    "no trademark",
)
FORBIDDEN_PHRASES = (
    "download on the app store",
    'href="#"',
    "placeholder",
    "third-party analytics",
    "reads imessage",
    "in-app voip",
)
ALLOWED_EXTERNAL_SCHEMES = ("https", "mailto", "tel")


@dataclass
class LinkReference:
    attribute: str
    target: str
    line: int


@dataclass
class ParsedHtml:
    title: str = ""
    meta_description: str = ""
    links: list[LinkReference] = field(default_factory=list)


class StaticSiteParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parsed = ParsedHtml()
        self._in_title = False
        self._title_parts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        normalized = dict(attrs)
        if tag == "title":
            self._in_title = True
        if tag == "meta" and normalized.get("name", "").lower() == "description":
            self.parsed.meta_description = (normalized.get("content") or "").strip()
        for attribute in ("href", "src"):
            value = normalized.get(attribute)
            if value:
                self.parsed.links.append(
                    LinkReference(
                        attribute=attribute, target=value.strip(), line=self.getpos()[0]
                    )
                )

    def handle_endtag(self, tag: str) -> None:
        if tag == "title":
            self._in_title = False
            self.parsed.title = " ".join("".join(self._title_parts).split())

    def handle_data(self, data: str) -> None:
        if self._in_title:
            self._title_parts.append(data)


def parse_html(value: str) -> ParsedHtml:
    parser = StaticSiteParser()
    parser.feed(value)
    parser.close()
    return parser.parsed


def html_files(root: Path) -> list[Path]:
    return sorted(path for path in root.rglob("*.html") if path.is_file())


def resolve_internal_target(root: Path, source: Path, raw_target: str) -> Path | None:
    target = raw_target.split("#", 1)[0].split("?", 1)[0]
    if not target:
        return None
    parsed = urlparse(target)
    if parsed.scheme:
        return None
    candidate = (
        root / unquote(target.lstrip("/"))
        if target.startswith("/")
        else source.parent / unquote(target)
    )
    if target.endswith("/") or candidate.is_dir():
        candidate = candidate / "index.html"
    return candidate.resolve()


def validate_internal_link(root: Path, source: Path, link: LinkReference) -> str | None:
    target = link.target
    parsed = urlparse(target)
    if parsed.scheme:
        if parsed.scheme not in ALLOWED_EXTERNAL_SCHEMES:
            return f"{source.relative_to(root)}:{link.line}: unsupported URL scheme {parsed.scheme!r}."
        if parsed.scheme == "http":
            return f"{source.relative_to(root)}:{link.line}: insecure URL {target!r}."
        return None
    if target == "#":
        return f'{source.relative_to(root)}:{link.line}: href="#" is not allowed.'
    candidate = resolve_internal_target(root, source, target)
    if candidate is None:
        return None
    try:
        candidate.relative_to(root.resolve())
    except ValueError:
        return f"{source.relative_to(root)}:{link.line}: link escapes web root: {target!r}."
    if not candidate.exists():
        return f"{source.relative_to(root)}:{link.line}: broken internal {link.attribute}={target!r}."
    return None


def validate_html_file(root: Path, path: Path) -> list[str]:
    errors: list[str] = []
    raw = path.read_text(encoding="utf-8")
    lowered = raw.lower()
    relative = path.relative_to(root)
    parsed = parse_html(raw)
    if "noindex" in lowered:
        errors.append(f"{relative}: must not contain noindex.")
    if "http://" in lowered:
        errors.append(f"{relative}: must not contain insecure http:// URLs.")
    if not parsed.title:
        errors.append(f"{relative}: missing non-empty <title>.")
    if not parsed.meta_description:
        errors.append(f"{relative}: missing non-empty meta description.")
    for email in REQUIRED_EMAILS_BY_FILE.get(relative, (CONTACT_EMAIL,)):
        if email not in raw:
            errors.append(f"{relative}: missing {email}.")
    if relative in REQUIRED_LICENSE_LINK_FILES and 'href="/license/"' not in raw:
        errors.append(f"{relative}: missing /license/ footer link.")
    if relative == Path("license/index.html"):
        for phrase in REQUIRED_LICENSE_PHRASES:
            if phrase not in lowered:
                errors.append(f"{relative}: missing license phrase {phrase!r}.")
    for phrase in FORBIDDEN_PHRASES:
        if phrase in lowered:
            errors.append(f"{relative}: contains forbidden copy {phrase!r}.")
    for link in parsed.links:
        if error := validate_internal_link(root, path, link):
            errors.append(error)
    return errors


def validate_site(root: Path) -> list[str]:
    resolved_root = root.resolve()
    errors: list[str] = []
    if not resolved_root.is_dir():
        return [f"Static site root not found: {root}"]
    for required_file in REQUIRED_FILES:
        if not (resolved_root / required_file).is_file():
            errors.append(f"Missing required static site file: {required_file}")
    robots = resolved_root / "robots.txt"
    if (
        robots.is_file()
        and "Sitemap: https://wechore.peyton.app/sitemap.xml"
        not in robots.read_text(encoding="utf-8")
    ):
        errors.append(
            "robots.txt must reference https://wechore.peyton.app/sitemap.xml."
        )
    sitemap = resolved_root / "sitemap.xml"
    if sitemap.is_file():
        sitemap_text = sitemap.read_text(encoding="utf-8")
        for path in ("/", "/support/", "/privacy/", "/license/"):
            expected = f"https://wechore.peyton.app{path}"
            if expected not in sitemap_text:
                errors.append(f"sitemap.xml missing {expected}.")
    aasa = resolved_root / ".well-known" / "apple-app-site-association"
    if aasa.is_file():
        try:
            payload = json.loads(aasa.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            errors.append(
                f".well-known/apple-app-site-association is invalid JSON: {error}."
            )
        else:
            details = payload.get("applinks", {}).get("details", [])
            if not any(
                entry.get("appID") == "3VDQ4656LX.app.peyton.wechore"
                and "/join*" in entry.get("paths", [])
                for entry in details
            ):
                errors.append(
                    ".well-known/apple-app-site-association missing production "
                    "/join* applink entry."
                )
    for path in html_files(resolved_root):
        errors.extend(validate_html_file(resolved_root, path))
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate the WeChore static site.")
    parser.add_argument("root", nargs="?", default="web")
    args = parser.parse_args(argv)
    errors = validate_site(Path(args.root))
    if errors:
        for error in errors:
            print(error)
        return 1
    print("Static site is valid.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
