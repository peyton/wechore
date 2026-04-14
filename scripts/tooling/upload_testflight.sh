#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

setup_local_tooling_env

# shellcheck disable=SC2153
archive_path="$REPO_ROOT/$ARCHIVE_PATH"
# shellcheck disable=SC2153
export_path="$REPO_ROOT/$EXPORT_PATH"
export_options_path="$REPO_ROOT/.build/exportOptions-testflight.plist"
skip_archive=0

while [ $# -gt 0 ]; do
  case "$1" in
  --archive-path)
    archive_path="$2"
    shift 2
    ;;
  --export-path)
    export_path="$2"
    shift 2
    ;;
  --skip-archive)
    skip_archive=1
    shift
    ;;
  *)
    printf 'Unknown argument: %s\n' "$1" >&2
    exit 2
    ;;
  esac
done

WECHORE_FLAVOR="prod"
APP_SCHEME="$RELEASE_APP_SCHEME"
APP_IDENTIFIER="$RELEASE_APP_IDENTIFIER"
WECHORE_CLOUD_KIT_ENVIRONMENT="${WECHORE_CLOUD_KIT_ENVIRONMENT:-Production}"
export WECHORE_FLAVOR APP_SCHEME APP_IDENTIFIER WECHORE_CLOUD_KIT_ENVIRONMENT
resolve_version_metadata
export_tuist_manifest_env

api_key_path="$("$TOOLING_DIR/appstore_api_key.sh")"

if [ "$skip_archive" -eq 0 ]; then
  "$TOOLING_DIR/archive_release.sh" --archive-path "$archive_path"
fi

if [ ! -d "$archive_path" ]; then
  printf 'Error: archive not found at %s\n' "$archive_path" >&2
  exit 2
fi

rm -rf "$export_path"
mkdir -p "$export_path" "$(dirname "$export_options_path")"

cat >"$export_options_path" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>upload</string>
  <key>iCloudContainerEnvironment</key>
  <string>Production</string>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
  <key>method</key>
  <string>app-store-connect</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
PLIST

xcodebuild \
  -exportArchive \
  -archivePath "$archive_path" \
  -exportPath "$export_path" \
  -exportOptionsPlist "$export_options_path" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$api_key_path" \
  -authenticationKeyID "$APP_STORE_CONNECT_API_KEY_ID" \
  -authenticationKeyIssuerID "$APP_STORE_CONNECT_API_ISSUER_ID"
