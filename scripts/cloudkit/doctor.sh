#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

setup_local_tooling_env
require_cktool

printf 'WeChore CloudKit configuration\n'
printf '  Team: %s\n' "$CLOUDKIT_TEAM_ID"
printf '  Container: %s\n' "$CLOUDKIT_CONTAINER_ID"
printf '  Environment: %s\n' "$CLOUDKIT_ENVIRONMENT"

if xcrun cktool get-teams >/tmp/wechore-cktool-teams.txt 2>/tmp/wechore-cktool-teams.err; then
  if grep -q "$CLOUDKIT_TEAM_ID" /tmp/wechore-cktool-teams.txt; then
    printf 'Validated CloudKit management access for team %s.\n' "$CLOUDKIT_TEAM_ID"
  else
    printf 'Configured CloudKit team %s is not visible to cktool.\n' "$CLOUDKIT_TEAM_ID" >&2
    exit 1
  fi
else
  printf 'cktool is available but CloudKit authentication is not configured.\n' >&2
  cat /tmp/wechore-cktool-teams.err >&2 || true
  exit 1
fi
