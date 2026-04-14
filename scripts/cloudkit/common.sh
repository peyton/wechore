#!/usr/bin/env bash
set -euo pipefail

CLOUDKIT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$CLOUDKIT_DIR/../.." && pwd)"

# shellcheck source=/dev/null
source "$REPO_ROOT/scripts/tooling/common.sh"

cloudkit_schema_path() {
  printf '%s/%s\n' "$REPO_ROOT" "$CLOUDKIT_SCHEMA_FILE"
}

require_cktool() {
  if ! xcrun cktool version >/dev/null 2>&1; then
    printf 'xcrun cktool is required for CloudKit schema commands.\n' >&2
    exit 1
  fi
}
