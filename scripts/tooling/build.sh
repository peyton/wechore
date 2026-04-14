#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

setup_local_tooling_env

configuration="Release"
destination="generic/platform=iOS"
derived_data_path=""
result_bundle_path=""
run_generate=1
code_signing="none"

while [ $# -gt 0 ]; do
  case "$1" in
  --configuration)
    configuration="$2"
    shift 2
    ;;
  --destination)
    destination="$2"
    shift 2
    ;;
  --derived-data-path)
    derived_data_path="$2"
    shift 2
    ;;
  --result-bundle-path)
    result_bundle_path="$2"
    shift 2
    ;;
  --skip-generate)
    run_generate=0
    shift
    ;;
  --signing)
    code_signing="$2"
    shift 2
    ;;
  *)
    printf 'Unknown argument: %s\n' "$1" >&2
    exit 2
    ;;
  esac
done

if [ -z "$derived_data_path" ]; then
  derived_data_path="$REPO_ROOT/$BUILD_DERIVED_DATA"
fi
if [ -z "$result_bundle_path" ]; then
  result_bundle_path="$REPO_ROOT/.build/build.xcresult"
fi

mkdir -p "$(dirname "$derived_data_path")" "$(dirname "$result_bundle_path")"
rm -rf "$result_bundle_path"

if [ "$run_generate" -eq 1 ]; then
  generate_workspace
fi

build_args=(
  -workspace "$REPO_ROOT/$APP_WORKSPACE"
  -scheme "$APP_SCHEME"
  -configuration "$configuration"
  -destination "$destination"
  -derivedDataPath "$derived_data_path"
  -resultBundlePath "$result_bundle_path"
)

if [ "$code_signing" = "none" ]; then
  build_args+=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)
fi

if should_disable_swift_compile_cache; then
  build_args+=(
    SWIFT_ENABLE_COMPILE_CACHE=NO
    COMPILATION_CACHE_ENABLE_CACHING=NO
    COMPILATION_CACHE_ENABLE_PLUGIN=NO
    COMPILATION_CACHE_REMOTE_SERVICE_PATH=
  )
fi

xcodebuild "${build_args[@]}" build
