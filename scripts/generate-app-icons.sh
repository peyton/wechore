#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_SVG="$ROOT_DIR/icon.svg"
ICONSET_DIR="$ROOT_DIR/app/WeChore/Resources/Assets.xcassets/AppIcon.appiconset"

if [ ! -f "$SOURCE_SVG" ]; then
  printf 'Missing icon source: %s\n' "$SOURCE_SVG" >&2
  exit 1
fi

if ! command -v sips >/dev/null 2>&1; then
  printf 'sips is required to render %s\n' "$SOURCE_SVG" >&2
  exit 1
fi

mkdir -p "$ICONSET_DIR"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

rendered_png="$tmp_dir/icon.png"
sips -s format png "$SOURCE_SVG" --out "$rendered_png" >/dev/null
sips -z 1024 1024 "$rendered_png" --out "$ICONSET_DIR/appicon-default.png" >/dev/null
cp "$ICONSET_DIR/appicon-default.png" "$ICONSET_DIR/appicon-dark.png"
cp "$ICONSET_DIR/appicon-default.png" "$ICONSET_DIR/appicon-tinted.png"

printf 'Generated app icons from %s\n' "$SOURCE_SVG"
