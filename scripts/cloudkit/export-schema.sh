#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

setup_local_tooling_env
require_cktool

schema_file="$(cloudkit_schema_path)"
mkdir -p "$(dirname "$schema_file")"

xcrun cktool export-schema \
  --container-id "$CLOUDKIT_CONTAINER_ID" \
  --environment "$CLOUDKIT_ENVIRONMENT" \
  --output-file "$schema_file"

printf 'Exported CloudKit schema to %s\n' "$schema_file"
