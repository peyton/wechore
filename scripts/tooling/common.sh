#!/usr/bin/env bash
set -euo pipefail

TOOLING_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$TOOLING_DIR/../.." && pwd)"

set -a
# shellcheck source=/dev/null
source "$TOOLING_DIR/wechore.env"
set +a

normalize_flavor() {
  case "${1:-dev}" in
  prod) printf 'prod' ;;
  *) printf 'dev' ;;
  esac
}

apply_flavor_defaults() {
  WECHORE_FLAVOR="$(normalize_flavor "${WECHORE_FLAVOR:-dev}")"

  if [ -z "${APP_SCHEME:-}" ]; then
    if [ "$WECHORE_FLAVOR" = "prod" ]; then
      APP_SCHEME="$RELEASE_APP_SCHEME"
    else
      APP_SCHEME="$DEV_APP_SCHEME"
    fi
  fi

  if [ -z "${APP_IDENTIFIER:-}" ]; then
    if [ "$WECHORE_FLAVOR" = "prod" ]; then
      APP_IDENTIFIER="$RELEASE_APP_IDENTIFIER"
    else
      APP_IDENTIFIER="$DEV_APP_IDENTIFIER"
    fi
  fi

  if [ -z "${RUN_APP_PATH:-}" ]; then
    if [ "$APP_SCHEME" = "$RELEASE_APP_SCHEME" ]; then
      RUN_APP_PATH="Build/Products/Debug-iphonesimulator/$RELEASE_APP_PRODUCT_NAME.app"
    else
      RUN_APP_PATH="Build/Products/Debug-iphonesimulator/$DEV_APP_PRODUCT_NAME.app"
    fi
  fi

  export WECHORE_FLAVOR APP_SCHEME APP_IDENTIFIER RUN_APP_PATH
}

resolve_version_metadata() {
  if [ "${WECHORE_SKIP_VERSION_RESOLUTION:-0}" = "1" ]; then
    return 0
  fi

  local exports
  if ! exports="$(run_repo_python_module scripts.tooling.resolve_versions --format shell)"; then
    printf 'Error: version resolution failed\n' >&2
    return 1
  fi
  eval "$exports"
  export WECHORE_MARKETING_VERSION WECHORE_BUILD_NUMBER
}

export_tuist_manifest_env() {
  export TUIST_WECHORE_MARKETING_VERSION="${WECHORE_MARKETING_VERSION:-}"
  export TUIST_WECHORE_BUILD_NUMBER="${WECHORE_BUILD_NUMBER:-}"
  export TUIST_WECHORE_CLOUD_KIT_ENVIRONMENT="${WECHORE_CLOUD_KIT_ENVIRONMENT:-Development}"
  export TUIST_TEAM_ID="${TEAM_ID:-}"
}

ensure_local_state() {
  mkdir -p \
    "$REPO_ROOT/.build" \
    "$REPO_ROOT/.cache/hk" \
    "$REPO_ROOT/.cache/npm" \
    "$REPO_ROOT/.cache/swiftlint" \
    "$REPO_ROOT/.cache/uv" \
    "$REPO_ROOT/.config/mise" \
    "$REPO_ROOT/.state/hk"
}

setup_local_tooling_env() {
  ensure_local_state

  export MISE_CONFIG_DIR="$REPO_ROOT/.config/mise"
  export UV_CACHE_DIR="$REPO_ROOT/.cache/uv"
  export UV_PROJECT_ENVIRONMENT="$REPO_ROOT/.venv"
  export HK_CACHE_DIR="$REPO_ROOT/.cache/hk"
  export HK_STATE_DIR="$REPO_ROOT/.state/hk"
  export npm_config_cache="$REPO_ROOT/.cache/npm"

  apply_flavor_defaults
  resolve_version_metadata
  export_tuist_manifest_env
}

run_mise() {
  command mise trust "$REPO_ROOT/mise.toml" >/dev/null 2>&1 || true
  mise "$@"
}

run_mise_exec() {
  run_mise exec -- "$@"
}

run_repo_python_module() {
  run_mise_exec uv run python -m "$@"
}

run_in_app() {
  (
    cd "$REPO_ROOT/app"
    "$@"
  )
}

generate_workspace() {
  if [ -f "$REPO_ROOT/app/Tuist/Package.resolved" ]; then
    run_in_app run_mise_exec tuist install --force-resolved-versions
  fi
  run_in_app run_mise_exec tuist generate --no-open
  touch "$REPO_ROOT/$APP_WORKSPACE/.tuist-generated"
}

workspace_is_generated() {
  [ -d "$REPO_ROOT/$APP_WORKSPACE" ]
}

workspace_has_scheme() {
  xcodebuild -list -workspace "$REPO_ROOT/$APP_WORKSPACE" 2>/dev/null |
    grep -Eq "^[[:space:]]+$APP_SCHEME$"
}

workspace_needs_regeneration() {
  local generation_marker="$REPO_ROOT/$APP_WORKSPACE/.tuist-generated"
  local manifest

  if [ ! -f "$generation_marker" ]; then
    return 0
  fi

  for manifest in \
    "$REPO_ROOT/app/Tuist.swift" \
    "$REPO_ROOT/app/Workspace.swift" \
    "$REPO_ROOT/app/Tuist/Package.swift" \
    "$REPO_ROOT/app/WeChore/Project.swift"; do
    if [ -e "$manifest" ] && [ "$manifest" -nt "$generation_marker" ]; then
      return 0
    fi
  done

  return 1
}

ensure_workspace_generated() {
  if workspace_is_generated && workspace_has_scheme && ! workspace_needs_regeneration; then
    return 0
  fi
  generate_workspace
}

resolve_simulator_udid() {
  run_repo_python_module scripts.resolve_simulator \
    --name "$1" \
    --device-type-name "$2"
}

is_beta_xcode() {
  xcodebuild -version 2>/dev/null | grep -qi 'beta' ||
    xcode-select -p 2>/dev/null | grep -qi 'beta'
}

should_disable_swift_compile_cache() {
  [ "${ACT:-}" = "true" ] ||
    [ "${WECHORE_DISABLE_SWIFT_COMPILE_CACHE:-0}" = "1" ] ||
    is_beta_xcode
}
