from __future__ import annotations

import shutil
import tarfile
from pathlib import Path

from scripts.web.package_static_site import package_site, sha256_file
from scripts.web.validate_static_site import validate_site


REPO_ROOT = Path(__file__).resolve().parents[1]


def test_committed_static_site_is_review_ready() -> None:
    assert validate_site(REPO_ROOT / "web") == []


def test_static_site_validator_rejects_missing_contact_and_broken_links(
    tmp_path: Path,
) -> None:
    site_root = tmp_path / "web"
    (site_root / "support").mkdir(parents=True)
    (site_root / "privacy").mkdir()
    (site_root / "assets").mkdir()
    (site_root / "assets" / "site.css").write_text(
        "body { color: #111; }\n", encoding="utf-8"
    )
    (site_root / "assets" / "app-icon.svg").write_text(
        "<svg></svg>\n", encoding="utf-8"
    )
    (site_root / "assets" / "app-preview.svg").write_text(
        "<svg></svg>\n", encoding="utf-8"
    )
    (site_root / "robots.txt").write_text("User-agent: *\nAllow: /\n", encoding="utf-8")
    (site_root / "sitemap.xml").write_text("<urlset></urlset>\n", encoding="utf-8")
    broken_page = """
    <!doctype html>
    <html lang="en">
      <head>
        <title>Broken</title>
        <meta name="description" content="Broken page">
      </head>
      <body><a href="/missing/">Missing</a></body>
    </html>
    """
    for relative_path in (
        "index.html",
        "support/index.html",
        "privacy/index.html",
        "404.html",
    ):
        (site_root / relative_path).write_text(broken_page, encoding="utf-8")

    errors = validate_site(site_root)

    assert any("missing contact@wechore.peyton.app" in error for error in errors)
    assert any("broken internal" in error for error in errors)
    assert any("robots.txt" in error for error in errors)


def test_static_site_validator_rejects_missing_license_notice(tmp_path: Path) -> None:
    site_root = tmp_path / "web"
    shutil.copytree(REPO_ROOT / "web", site_root)
    license_page = site_root / "license" / "index.html"
    license_page.write_text(
        license_page.read_text(encoding="utf-8").replace("No license is granted", ""),
        encoding="utf-8",
    )
    index_page = site_root / "index.html"
    index_page.write_text(
        index_page.read_text(encoding="utf-8").replace(
            '<a href="/license/">License</a>', ""
        ),
        encoding="utf-8",
    )

    errors = validate_site(site_root)

    assert any(
        "index.html: missing /license/ footer link." in error for error in errors
    )
    assert any(
        "missing license phrase 'no license is granted'" in error for error in errors
    )


def test_static_site_package_contains_relative_site_files(tmp_path: Path) -> None:
    source_root = tmp_path / "web-build"
    source_root.mkdir()
    (source_root / "assets").mkdir()
    (source_root / "index.html").write_text("<!doctype html>\n", encoding="utf-8")
    (source_root / "assets" / "site.css").write_text(
        "body { color: #111; }\n", encoding="utf-8"
    )
    output_dir = tmp_path / "releases"

    result = package_site(source_root, "1.2.3", output_dir)

    assert result.archive_path == output_dir / "wechore-web-1.2.3.tar.gz"
    assert result.checksum_path == output_dir / "wechore-web-1.2.3.tar.gz.sha256"
    assert result.digest == sha256_file(result.archive_path)
    with tarfile.open(result.archive_path, "r:gz") as archive:
        assert archive.getnames() == ["assets/site.css", "index.html"]
        for member in archive.getmembers():
            assert member.uid == 0
            assert member.gid == 0
            assert member.mtime == 0
