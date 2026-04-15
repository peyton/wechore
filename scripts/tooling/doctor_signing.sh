#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

ensure_local_state

#
# WeChore Signing & CI Doctor
#
# Walks through every environment variable, credential, profile, and
# entitlement that the GitHub Actions workflows and justfile recipes need
# to archive, sign, and upload to TestFlight / App Store Connect.
#

pass=0
warn=0
fail=0
section_count=0

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

ok() { pass=$((pass + 1)); printf '  %b[ok]%b    %s\n' "$GREEN" "$RESET" "$1"; }
skip() { warn=$((warn + 1)); printf '  %b[skip]%b  %s\n' "$YELLOW" "$RESET" "$1"; }
bad() { fail=$((fail + 1)); printf '  %b[FAIL]%b  %s\n' "$RED" "$RESET" "$1"; }
hint() { printf '          %b%s%b\n' "$DIM" "$1" "$RESET"; }

section() {
  section_count=$((section_count + 1))
  printf '\n%b%d. %s%b\n' "$BLUE$BOLD" "$section_count" "$1" "$RESET"
}

# ── 1. Apple Team ID ────────────────────────────────────────────────
section "Apple Team ID"

if [ -n "${TEAM_ID:-}" ]; then
  if [[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
    ok "TEAM_ID=$TEAM_ID"
  else
    bad "TEAM_ID=$TEAM_ID (must be exactly 10 alphanumeric characters)"
  fi
else
  bad "TEAM_ID is not set"
  hint "export TEAM_ID=3VDQ4656LX"
  hint "In GitHub: add variable APPLE_TEAM_ID=3VDQ4656LX to the 'testflight' environment"
fi

# ── 2. App Store Connect API credentials ────────────────────────────
section "App Store Connect API Credentials"

if [ -n "${APP_STORE_CONNECT_API_KEY_ID:-}" ]; then
  ok "APP_STORE_CONNECT_API_KEY_ID is set (${APP_STORE_CONNECT_API_KEY_ID})"
else
  bad "APP_STORE_CONNECT_API_KEY_ID is not set"
  hint "Get this from App Store Connect > Users and Access > Integrations > Keys"
  hint "GitHub secret: APP_STORE_CONNECT_API_KEY_ID in 'testflight' environment"
fi

if [ -n "${APP_STORE_CONNECT_API_ISSUER_ID:-}" ]; then
  ok "APP_STORE_CONNECT_API_ISSUER_ID is set (${APP_STORE_CONNECT_API_ISSUER_ID})"
else
  bad "APP_STORE_CONNECT_API_ISSUER_ID is not set"
  hint "Get this from App Store Connect > Users and Access > Integrations > Keys"
  hint "The Issuer ID is shown at the top of the Keys page"
  hint "GitHub secret: APP_STORE_CONNECT_API_ISSUER_ID in 'testflight' environment"
fi

key_source=""
if [ -n "${APP_STORE_CONNECT_API_KEY_PATH:-}" ] && [ -f "${APP_STORE_CONNECT_API_KEY_PATH}" ]; then
  key_source="file"
  ok "APP_STORE_CONNECT_API_KEY_PATH points to an existing file"
elif [ -n "${APP_STORE_CONNECT_API_KEY_PATH:-}" ]; then
  bad "APP_STORE_CONNECT_API_KEY_PATH is set but file does not exist: ${APP_STORE_CONNECT_API_KEY_PATH}"
fi

if [ -n "${APP_STORE_CONNECT_API_KEY_P8_BASE64:-}" ]; then
  if [ -z "$key_source" ]; then
    key_source="base64"
  fi
  ok "APP_STORE_CONNECT_API_KEY_P8_BASE64 is set"
elif [ -n "${APP_STORE_CONNECT_API_KEY_P8:-}" ]; then
  if [ -z "$key_source" ]; then
    key_source="raw"
  fi
  ok "APP_STORE_CONNECT_API_KEY_P8 is set (raw PEM)"
fi

if [ -z "$key_source" ]; then
  bad "No App Store Connect private key found"
  hint "Set one of:"
  hint "  APP_STORE_CONNECT_API_KEY_PATH=/path/to/AuthKey_<KEY_ID>.p8   (local)"
  hint "  APP_STORE_CONNECT_API_KEY_P8_BASE64=<base64>                  (CI)"
  hint ""
  hint "To create the base64 value for CI:"
  hint "  base64 -i AuthKey_<KEY_ID>.p8 | tr -d '\\n'"
  hint ""
  hint "GitHub secret: APP_STORE_CONNECT_API_KEY_P8_BASE64 in 'testflight' environment"
else
  ok "Private key source: $key_source"
fi

# Try to materialize the key and validate it
if [ -n "${APP_STORE_CONNECT_API_KEY_ID:-}" ]; then
  state_key_path="$REPO_ROOT/.state/appstoreconnect/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"
  if [ -n "${APP_STORE_CONNECT_API_KEY_PATH:-}" ] && [ -f "${APP_STORE_CONNECT_API_KEY_PATH}" ]; then
    if head -n 1 "${APP_STORE_CONNECT_API_KEY_PATH}" | grep -q 'BEGIN PRIVATE KEY'; then
      ok "Private key file looks like a valid PEM key"
    else
      bad "Private key file does not start with PEM header"
      hint "The .p8 file should start with: -----BEGIN PRIVATE KEY-----"
    fi
  elif [ -f "$state_key_path" ]; then
    ok "Cached key exists at $state_key_path"
  fi
fi

# ── 3. Xcode & signing tools ────────────────────────────────────────
section "Xcode & Signing Tools"

if command -v xcodebuild >/dev/null 2>&1; then
  xcode_version="$(xcodebuild -version 2>/dev/null | head -n 1 || echo 'unknown')"
  ok "xcodebuild available ($xcode_version)"
else
  skip "xcodebuild not found (expected on macOS CI runners)"
  hint "This check passes on macOS; on Linux it is expected to be missing"
fi

if command -v security >/dev/null 2>&1; then
  ok "security command available (keychain management)"
else
  skip "security command not found (expected on macOS)"
fi

if command -v codesign >/dev/null 2>&1; then
  ok "codesign command available"
else
  skip "codesign command not found (expected on macOS)"
fi

# ── 4. Tuist environment variables ──────────────────────────────────
section "Tuist Environment Variables"

hint "These are set automatically by scripts/tooling/common.sh and passed to"
hint "Tuist via the TUIST_ prefix. Showing current effective values:"

printf '  %b·%b TUIST_TEAM_ID=%s\n' "$DIM" "$RESET" "${TUIST_TEAM_ID:-${TEAM_ID:-"(unset)"}}"
printf '  %b·%b TUIST_WECHORE_MARKETING_VERSION=%s\n' "$DIM" "$RESET" "${TUIST_WECHORE_MARKETING_VERSION:-${WECHORE_MARKETING_VERSION:-"(will be resolved from git tags)"}}"
printf '  %b·%b TUIST_WECHORE_BUILD_NUMBER=%s\n' "$DIM" "$RESET" "${TUIST_WECHORE_BUILD_NUMBER:-${WECHORE_BUILD_NUMBER:-"(will be resolved at build time)"}}"
printf '  %b·%b TUIST_WECHORE_CLOUD_KIT_ENVIRONMENT=%s\n' "$DIM" "$RESET" "${TUIST_WECHORE_CLOUD_KIT_ENVIRONMENT:-${WECHORE_CLOUD_KIT_ENVIRONMENT:-Development}}"

ok "Tuist variables are auto-populated from export_tuist_manifest_env()"

# ── 5. Entitlements files ───────────────────────────────────────────
section "Entitlements Files"

app_entitlements="$REPO_ROOT/app/WeChore/WeChore.entitlements"
widget_entitlements="$REPO_ROOT/app/WeChore/WidgetExtension/WeChoreWidget.entitlements"

if [ -f "$app_entitlements" ]; then
  ok "Main app entitlements: WeChore.entitlements"
  hint "Capabilities: iCloud/CloudKit, App Groups, Associated Domains"
else
  bad "Missing: app/WeChore/WeChore.entitlements"
fi

if [ -f "$widget_entitlements" ]; then
  ok "Widget entitlements: WidgetExtension/WeChoreWidget.entitlements"
  hint "Capabilities: App Groups (shared with main app)"
else
  bad "Missing: app/WeChore/WidgetExtension/WeChoreWidget.entitlements"
fi

# ── 6. Info.plist & Privacy Manifest ────────────────────────────────
section "Release Metadata Files"

info_plist="$REPO_ROOT/app/WeChore/Info.plist"
privacy_manifest="$REPO_ROOT/app/WeChore/Resources/PrivacyInfo.xcprivacy"
aasa="$REPO_ROOT/web/.well-known/apple-app-site-association"

if [ -f "$info_plist" ]; then
  ok "Info.plist exists"
else
  bad "Missing: app/WeChore/Info.plist"
fi

if [ -f "$privacy_manifest" ]; then
  ok "PrivacyInfo.xcprivacy exists"
else
  bad "Missing: app/WeChore/Resources/PrivacyInfo.xcprivacy"
fi

if [ -f "$aasa" ]; then
  ok "Apple App Site Association file exists"
else
  bad "Missing: web/.well-known/apple-app-site-association"
fi

# ── 7. Preflight validation ─────────────────────────────────────────
section "Release Preflight Validation"

hint "Running: scripts.app_store_connect.preflight (without --require-credentials)"

preflight_output=""
if preflight_output="$(WECHORE_FLAVOR=prod WECHORE_CLOUD_KIT_ENVIRONMENT=Production \
  run_repo_python_module scripts.app_store_connect.preflight 2>&1)"; then
  ok "Preflight passed (metadata, entitlements, privacy manifest, AASA)"
else
  bad "Preflight failed (exit $?)"
  while IFS= read -r line; do
    hint "  $line"
  done <<< "$preflight_output"
fi

# ── 8. App Store Connect API connectivity ───────────────────────────
section "App Store Connect API Connectivity"

if [ -n "${APP_STORE_CONNECT_API_KEY_ID:-}" ] &&
  [ -n "${APP_STORE_CONNECT_API_ISSUER_ID:-}" ] &&
  [ -n "$key_source" ]; then

  hint "Running: scripts.app_store_connect.check_asc"
  asc_output=""
  if asc_output="$(WECHORE_FLAVOR=prod \
    run_repo_python_module scripts.app_store_connect.check_asc 2>&1)"; then
    ok "App Store Connect app found"
    hint "  $asc_output"
  else
    asc_rc=$?
    if [ "$asc_rc" -eq 3 ]; then
      bad "App record not found in App Store Connect"
      hint "Create the app in App Store Connect:"
      hint "  Name: WeChore"
      hint "  Bundle ID: app.peyton.wechore"
      hint "  SKU: WECHORE-IOS"
      hint "  Primary locale: en-US"
      hint "  Platform: iOS"
      hint "  Version: 1.0.0"
      hint "Or run: just appstore-create-app"
    else
      bad "App Store Connect check failed (exit $asc_rc)"
      while IFS= read -r line; do
        hint "  $line"
      done <<< "$asc_output"
    fi
  fi
else
  skip "Skipping App Store Connect API check (credentials not fully configured)"
  hint "Set the three API credentials above to enable this check"
fi

# ── 9. Provisioning profile status ──────────────────────────────────
section "Provisioning Profile Status"

if [ -n "${APP_STORE_CONNECT_API_KEY_ID:-}" ] &&
  [ -n "${APP_STORE_CONNECT_API_ISSUER_ID:-}" ] &&
  [ -n "$key_source" ]; then

  hint "Running: scripts.app_store_connect.provisioning --dry-run"
  prov_output=""
  if prov_output="$(WECHORE_FLAVOR=prod WECHORE_CLOUD_KIT_ENVIRONMENT=Production \
    run_repo_python_module scripts.app_store_connect.provisioning --dry-run 2>&1)"; then
    ok "Provisioning plan generated"
    while IFS= read -r line; do
      hint "  $line"
    done <<< "$prov_output"
  else
    bad "Provisioning check failed (exit $?)"
    while IFS= read -r line; do
      hint "  $line"
    done <<< "$prov_output"
  fi
else
  skip "Skipping provisioning check (credentials not fully configured)"
fi

# ── 10. GitHub environment checklist ────────────────────────────────
section "GitHub Actions Environment Checklist"

printf '  %bThe TestFlight workflow needs these values in the %b"testflight"%b GitHub environment:%b\n' "$DIM" "$BOLD" "$DIM" "$RESET"
printf '\n'
printf '  %bSecrets:%b\n' "$BOLD" "$RESET"
printf '    APP_STORE_CONNECT_API_KEY_ID        %b# Key ID from ASC > Integrations > Keys%b\n' "$DIM" "$RESET"
printf '    APP_STORE_CONNECT_API_ISSUER_ID      %b# Issuer ID (top of Keys page)%b\n' "$DIM" "$RESET"
printf '    APP_STORE_CONNECT_API_KEY_P8_BASE64  %b# base64 -i AuthKey_<ID>.p8 | tr -d '"'"'\\n'"'"'%b\n' "$DIM" "$RESET"
printf '\n'
printf '  %bVariables:%b\n' "$BOLD" "$RESET"
printf '    APPLE_TEAM_ID=3VDQ4656LX             %b# Apple Developer Team ID%b\n' "$DIM" "$RESET"
printf '\n'
printf '  %bTo set up the GitHub environment:%b\n' "$DIM" "$RESET"
printf '    1. Go to repo Settings > Environments > New environment > "testflight"\n'
printf '    2. Add each secret above under Environment secrets\n'
printf '    3. Add APPLE_TEAM_ID under Environment variables\n'
printf '    4. Optionally restrict to the "master" branch for safety\n'
printf '\n'

# ── 11. Local development setup ─────────────────────────────────────
section "Local Development Setup"

printf '  %bFor local TestFlight uploads, export these in your shell:%b\n' "$DIM" "$RESET"
printf '\n'
printf '    export APP_STORE_CONNECT_API_KEY_ID=<your-key-id>\n'
printf '    export APP_STORE_CONNECT_API_ISSUER_ID=<your-issuer-id>\n'
printf '    export APP_STORE_CONNECT_API_KEY_PATH=/path/to/AuthKey_<KEY_ID>.p8\n'
printf '    export TEAM_ID=3VDQ4656LX\n'
printf '\n'
printf '  %bThen run:%b\n' "$DIM" "$RESET"
printf '    just appstore-preflight           %b# Validate metadata%b\n' "$DIM" "$RESET"
printf '    just appstore-check               %b# Verify ASC app exists%b\n' "$DIM" "$RESET"
printf '    just appstore-ensure-provisioning  %b# Create bundle IDs & profiles%b\n' "$DIM" "$RESET"
printf '    just testflight-upload             %b# Archive, sign, and upload%b\n' "$DIM" "$RESET"
printf '\n'

# ── 12. Common issues ───────────────────────────────────────────────
section "Common CI Signing Issues"

printf '  %bProvisioning profile errors:%b\n' "$BOLD" "$RESET"
printf '    If xcodebuild fails with "no provisioning profile" errors, run:\n'
printf '      just appstore-ensure-provisioning\n'
printf '    This creates IOS_APP_STORE profiles via the App Store Connect API.\n'
printf '    The archive step also uses -allowProvisioningUpdates, which lets\n'
printf '    Xcode create/renew profiles automatically using the API key.\n'
printf '\n'
printf '  %bCertificate errors:%b\n' "$BOLD" "$RESET"
printf '    The API key with Admin role lets Xcode manage certificates via\n'
printf '    -allowProvisioningUpdates. If you see "no signing certificate":\n'
printf '    1. Check the Apple Developer portal for an active Apple Distribution cert\n'
printf '    2. If expired, create a new one in Xcode or the portal\n'
printf '    3. The CI runner does NOT need the cert in its keychain --\n'
printf '       -allowProvisioningUpdates + API key auth handles this\n'
printf '\n'
printf '  %bEntitlement mismatches:%b\n' "$BOLD" "$RESET"
printf '    Entitlements reference build-setting variables:\n'
printf '      $(WECHORE_ICLOUD_CONTAINER)    = iCloud.app.peyton.wechore\n'
printf '      $(WECHORE_ICLOUD_ENVIRONMENT)  = Development or Production\n'
printf '      $(WECHORE_APP_GROUP_ID)         = group.app.peyton.wechore\n'
printf '    These are set by Tuist in Project.swift via flavorBuildSettings().\n'
printf '    If profiles reject entitlements, run:\n'
printf '      just appstore-provisioning-plan\n'
printf '    to verify the expected capabilities match what is registered.\n'
printf '\n'
printf '  %bCloudKit environment:%b\n' "$BOLD" "$RESET"
printf '    TestFlight builds MUST use WECHORE_CLOUD_KIT_ENVIRONMENT=Production.\n'
printf '    The testflight workflow and justfile recipes set this automatically.\n'
printf '    Local dev defaults to Development, which is correct for simulators.\n'
printf '\n'
printf '  %bAutomatic vs Manual signing:%b\n' "$BOLD" "$RESET"
printf '    This project uses Automatic signing (CODE_SIGN_STYLE=Automatic).\n'
printf '    Xcode + the ASC API key handle certificate and profile selection.\n'
printf '    Do NOT switch to Manual signing or import .mobileprovision files.\n'
printf '    The -authenticationKeyPath flags in archive/export scripts give\n'
printf '    xcodebuild the authority to manage signing on CI without a keychain.\n'
printf '\n'

# ── Summary ──────────────────────────────────────────────────────────
printf '\n%b── Summary ──%b\n' "$BOLD" "$RESET"
printf '  %b%d passed%b  ' "$GREEN" "$pass" "$RESET"
printf '%b%d warnings%b  ' "$YELLOW" "$warn" "$RESET"
printf '%b%d failed%b\n\n' "$RED" "$fail" "$RESET"

if [ "$fail" -gt 0 ]; then
  printf '%bFix the failures above before running testflight-upload or pushing to master.%b\n' "$RED" "$RESET"
  exit 1
elif [ "$warn" -gt 0 ]; then
  printf '%bWarnings are OK for local development but may cause CI failures.%b\n' "$YELLOW" "$RESET"
  exit 0
else
  printf '%bAll checks passed. Signing and TestFlight upload should work.%b\n' "$GREEN" "$RESET"
  exit 0
fi
