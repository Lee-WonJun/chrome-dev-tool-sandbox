#!/usr/bin/env bash

set -Eeuo pipefail

CDP_PROXY_BIND_ADDRESS=${CDP_PROXY_BIND_ADDRESS:-0.0.0.0}
CDP_PROXY_PORT=${CDP_PROXY_PORT:-9223}
CHROME_DEBUG_ADDRESS=${CHROME_DEBUG_ADDRESS:-127.0.0.1}
CHROME_DEBUG_PORT=${CHROME_DEBUG_PORT:-9222}
CHROME_USER_DATA_DIR=${CHROME_USER_DATA_DIR:-/config/chrome-debug-profile}
EXTRA_CHROME_CLI=${EXTRA_CHROME_CLI:-}

validate_port() {
  local label="$1"
  local value="$2"

  if ! [[ "$value" =~ ^[0-9]+$ ]] || (( value < 1 || value > 65535 )); then
    echo "[entrypoint] Invalid ${label}: ${value}" >&2
    exit 1
  fi
}

validate_port "CDP_PROXY_PORT" "$CDP_PROXY_PORT"
validate_port "CHROME_DEBUG_PORT" "$CHROME_DEBUG_PORT"

echo "[entrypoint] CDP proxy ${CDP_PROXY_BIND_ADDRESS}:${CDP_PROXY_PORT} -> ${CHROME_DEBUG_ADDRESS}:${CHROME_DEBUG_PORT}"
echo "[entrypoint] Chrome profile directory: ${CHROME_USER_DATA_DIR}"
if [[ -n "${EXTRA_CHROME_CLI}" ]]; then
  echo "[entrypoint] Extra Chrome flags detected: ${EXTRA_CHROME_CLI}"
fi

if [[ -d "${CHROME_USER_DATA_DIR}" ]]; then
  rm -f \
    "${CHROME_USER_DATA_DIR}"/SingletonCookie \
    "${CHROME_USER_DATA_DIR}"/SingletonLock \
    "${CHROME_USER_DATA_DIR}"/SingletonSocket \
    "${CHROME_USER_DATA_DIR}"/.com.google.Chrome.*
fi

socat "TCP-LISTEN:${CDP_PROXY_PORT},bind=${CDP_PROXY_BIND_ADDRESS},fork,reuseaddr" "TCP:${CHROME_DEBUG_ADDRESS}:${CHROME_DEBUG_PORT}" &

exec /init
