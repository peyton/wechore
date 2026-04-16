#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

setup_local_tooling_env

if [ -z "${APP_STORE_CONNECT_API_KEY_ID:-}" ]; then
  printf 'Error: APP_STORE_CONNECT_API_KEY_ID is required.\n' >&2
  exit 2
fi
if [ -z "${APP_STORE_CONNECT_API_ISSUER_ID:-}" ]; then
  printf 'Error: APP_STORE_CONNECT_API_ISSUER_ID is required.\n' >&2
  exit 2
fi

key_path="${APP_STORE_CONNECT_API_KEY_PATH:-}"
if [ -z "$key_path" ]; then
  key_path="$REPO_ROOT/.state/appstoreconnect/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"
fi

if [ ! -f "$key_path" ]; then
  if [ -z "${APP_STORE_CONNECT_API_KEY_P8_BASE64:-}" ] && [ -z "${APP_STORE_CONNECT_API_KEY_P8:-}" ]; then
    printf 'Error: %s does not exist and no App Store Connect private key env var is set.\n' "$key_path" >&2
    exit 2
  fi
  mkdir -p "$(dirname "$key_path")"
  APP_STORE_CONNECT_API_KEY_OUTPUT="$key_path" run_mise_exec uv run python -c \
    'import os, pathlib; from scripts.app_store_connect.check import load_private_key_pem; pathlib.Path(os.environ["APP_STORE_CONNECT_API_KEY_OUTPUT"]).write_bytes(load_private_key_pem(os.environ))'
  chmod 600 "$key_path"
fi

printf '%s\n' "$key_path"
