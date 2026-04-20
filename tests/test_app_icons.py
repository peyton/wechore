from __future__ import annotations

import json
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
APP_ICONSET = (
    REPO_ROOT
    / "app"
    / "WeChore"
    / "Resources"
    / "Assets.xcassets"
    / "AppIcon.appiconset"
)


def png_has_alpha(path: Path) -> bool:
    data = path.read_bytes()
    assert data.startswith(b"\x89PNG\r\n\x1a\n"), f"{path} is not a PNG"

    color_type = data[25]
    if color_type in {4, 6}:
        return True

    offset = 8
    while offset < len(data):
        chunk_length = int.from_bytes(data[offset : offset + 4], "big")
        chunk_type = data[offset + 4 : offset + 8]
        if chunk_type == b"tRNS":
            return True
        offset += 12 + chunk_length

    return False


def app_icon_filenames() -> list[str]:
    contents = json.loads((APP_ICONSET / "Contents.json").read_text(encoding="utf-8"))
    return [image["filename"] for image in contents["images"]]


def test_app_store_icon_assets_do_not_have_alpha_channels() -> None:
    for filename in app_icon_filenames():
        assert not png_has_alpha(APP_ICONSET / filename), filename
