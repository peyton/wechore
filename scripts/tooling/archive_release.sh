#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

setup_local_tooling_env

configuration="Release"
destination="generic/platform=iOS"
derived_data_path="$REPO_ROOT/$ARCHIVE_DERIVED_DATA"
# shellcheck disable=SC2153
archive_path="$REPO_ROOT/$ARCHIVE_PATH"
result_bundle_path="$REPO_ROOT/.build/archive.xcresult"
run_generate=1

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
  --archive-path)
    archive_path="$2"
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
run_repo_python_module scripts.app_store_connect.preflight --require-credentials

api_key_path="$("$TOOLING_DIR/appstore_api_key.sh")"

mkdir -p \
  "$(dirname "$archive_path")" \
  "$(dirname "$derived_data_path")" \
  "$(dirname "$result_bundle_path")"
rm -rf "$archive_path" "$result_bundle_path"

if [ "$run_generate" -eq 1 ]; then
  generate_workspace
fi

archive_args=(
  -workspace "$REPO_ROOT/$APP_WORKSPACE"
  -scheme "$APP_SCHEME"
  -configuration "$configuration"
  -destination "$destination"
  -derivedDataPath "$derived_data_path"
  -archivePath "$archive_path"
  -resultBundlePath "$result_bundle_path"
  -allowProvisioningUpdates
  -authenticationKeyPath "$api_key_path"
  -authenticationKeyID "$APP_STORE_CONNECT_API_KEY_ID"
  -authenticationKeyIssuerID "$APP_STORE_CONNECT_API_ISSUER_ID"
  archive
)

if should_disable_swift_compile_cache; then
  archive_args+=(
    SWIFT_ENABLE_COMPILE_CACHE=NO
    COMPILATION_CACHE_ENABLE_CACHING=NO
    COMPILATION_CACHE_ENABLE_PLUGIN=NO
    COMPILATION_CACHE_REMOTE_SERVICE_PATH=
  )
fi

xcodebuild "${archive_args[@]}"
