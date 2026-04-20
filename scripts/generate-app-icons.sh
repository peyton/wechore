#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICON_RENDERER="$ROOT_DIR/scripts/tooling/generate_app_icon.swift"
ICONSET_DIR="$ROOT_DIR/app/WeChore/Resources/Assets.xcassets/AppIcon.appiconset"

if [ ! -f "$ICON_RENDERER" ]; then
  printf 'Missing icon renderer: %s\n' "$ICON_RENDERER" >&2
  exit 1
fi

if ! xcrun --find swift >/dev/null 2>&1; then
  printf 'xcrun swift is required to flatten app icons without alpha\n' >&2
  exit 1
fi

mkdir -p "$ICONSET_DIR"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

rendered_png="$tmp_dir/appicon-default.png"
xcrun swift "$ICON_RENDERER" \
  "$rendered_png" \
  07c160
cp "$rendered_png" "$ICONSET_DIR/appicon-default.png"
cp "$ICONSET_DIR/appicon-default.png" "$ICONSET_DIR/appicon-dark.png"
cp "$ICONSET_DIR/appicon-default.png" "$ICONSET_DIR/appicon-tinted.png"

printf 'Generated app icons at %s\n' "$ICONSET_DIR"
