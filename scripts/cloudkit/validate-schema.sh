#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

setup_local_tooling_env

schema_file="$(cloudkit_schema_path)"
if [ ! -f "$schema_file" ]; then
  printf 'CloudKit schema file not found: %s\n' "$schema_file" >&2
  printf 'Run just cloudkit-export-schema after configuring cktool.\n' >&2
  exit 1
fi

uv run python -m json.tool "$schema_file" >/dev/null
printf 'Validated CloudKit schema JSON at %s\n' "$schema_file"
