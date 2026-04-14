#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

setup_local_tooling_env

suite=""
device="iphone"

while [ $# -gt 0 ]; do
  case "$1" in
  --suite)
    suite="$2"
    shift 2
    ;;
  --device)
    device="$2"
    shift 2
    ;;
  *)
    printf 'Unknown argument: %s\n' "$1" >&2
    exit 2
    ;;
  esac
done

case "$suite" in
unit)
  only_testing="WeChoreTests"
  ;;
integration)
  only_testing="WeChoreIntegrationTests"
  ;;
ui)
  only_testing="WeChoreUITests/WeChoreUITests"
  ;;
*)
  printf 'Missing or invalid --suite. Use unit, integration, or ui.\n' >&2
  exit 2
  ;;
esac

if [ "$device" = "ipad" ]; then
  simulator_name="$TEST_IPAD_SIMULATOR_NAME"
  simulator_device="$DEFAULT_IPAD_DEVICE"
else
  simulator_name="$TEST_IPHONE_SIMULATOR_NAME"
  simulator_device="$DEFAULT_IPHONE_DEVICE"
fi

ensure_workspace_generated

result_bundle_path="$REPO_ROOT/.build/test-$suite-$device.xcresult"
xcodebuild_log_path="$REPO_ROOT/.build/test-$suite-$device.xcodebuild.log"
read -r -a test_xcodebuild_args <<<"${TEST_XCODEBUILD_ARGS:-}"
test_scheme="${TEST_APP_SCHEME:-$RELEASE_APP_SCHEME}"
simulator_udid="$(resolve_simulator_udid "$simulator_name" "$simulator_device")"

reset_test_simulator() {
  xcrun simctl shutdown "$simulator_udid" >/dev/null 2>&1 || true
  xcrun simctl erase "$simulator_udid" >/dev/null 2>&1 || true
}

is_simulator_launch_error() {
  grep -Eq \
    'CoreSimulatorService|Mach error -308|Invalid device state|Failed to install or launch the test runner|Simulator device failed to launch|FBSOpenApplicationServiceErrorDomain' \
    "$xcodebuild_log_path"
}

has_xctest_failure() {
  grep -Eq ':[0-9]+: error: -\[|XCTAssert|Test Case .+ failed' "$xcodebuild_log_path"
}

reset_test_simulator

xcodebuild_args=(
  test
  -workspace "$REPO_ROOT/$APP_WORKSPACE"
  -scheme "$test_scheme"
  -configuration Debug
  -destination "id=$simulator_udid"
  -derivedDataPath "$REPO_ROOT/$TEST_DERIVED_DATA"
  -resultBundlePath "$result_bundle_path"
  "-only-testing:$only_testing"
  "${test_xcodebuild_args[@]}"
)

if should_disable_swift_compile_cache; then
  xcodebuild_args+=(
    SWIFT_ENABLE_COMPILE_CACHE=NO
    COMPILATION_CACHE_ENABLE_CACHING=NO
    COMPILATION_CACHE_ENABLE_PLUGIN=NO
    COMPILATION_CACHE_REMOTE_SERVICE_PATH=
  )
fi

mkdir -p "$REPO_ROOT/.build"
max_attempts="${TEST_XCODEBUILD_MAX_ATTEMPTS:-3}"
attempt=1

while true; do
  rm -rf "$result_bundle_path"
  set +e
  xcodebuild "${xcodebuild_args[@]}" 2>&1 | tee "$xcodebuild_log_path"
  status=${PIPESTATUS[0]}
  set -e

  if [ "$status" -eq 0 ]; then
    break
  fi

  if [ "$attempt" -ge "$max_attempts" ] || has_xctest_failure || ! is_simulator_launch_error; then
    exit "$status"
  fi

  attempt=$((attempt + 1))
  printf 'xcodebuild hit a simulator launch error; resetting simulator and retrying (%s/%s).\n' "$attempt" "$max_attempts"
  reset_test_simulator
  killall -9 com.apple.CoreSimulator.CoreSimulatorService >/dev/null 2>&1 || true
  sleep 2
done
