#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

setup_local_tooling_env

simulator_udid="$(resolve_simulator_udid "$RUN_SIMULATOR_NAME" "$DEFAULT_IPHONE_DEVICE")"
derived_data_path="$REPO_ROOT/$RUN_DERIVED_DATA"

bash "$TOOLING_DIR/build.sh" \
  --configuration Debug \
  --destination "id=$simulator_udid" \
  --derived-data-path "$derived_data_path" \
  --result-bundle-path "$REPO_ROOT/.build/run.xcresult"

app_path="$derived_data_path/$RUN_APP_PATH"

xcrun simctl boot "$simulator_udid" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$simulator_udid" -b
xcrun simctl install "$simulator_udid" "$app_path"
xcrun simctl launch "$simulator_udid" "$APP_IDENTIFIER"
