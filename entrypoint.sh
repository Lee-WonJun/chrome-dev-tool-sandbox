#!/usr/bin/env bash

set -Eeuo pipefail

CDP_PROXY_BIND_ADDRESS=${CDP_PROXY_BIND_ADDRESS:-0.0.0.0}
CDP_PROXY_PORT=${CDP_PROXY_PORT:-9223}
CHROME_DEBUG_ADDRESS=${CHROME_DEBUG_ADDRESS:-127.0.0.1}
CHROME_DEBUG_PORT=${CHROME_DEBUG_PORT:-9222}
CHROME_USER_DATA_DIR=${CHROME_USER_DATA_DIR:-/config/chrome-debug-profile}
CHROME_SESSION_RESTORE_ENABLED=${CHROME_SESSION_RESTORE_ENABLED:-true}
EXTRA_CHROME_CLI=${EXTRA_CHROME_CLI:-}

validate_port() {
  local label="$1"
  local value="$2"

  if ! [[ "$value" =~ ^[0-9]+$ ]] || (( value < 1 || value > 65535 )); then
    echo "[entrypoint] Invalid ${label}: ${value}" >&2
    exit 1
  fi
}

is_truthy() {
  case "${1,,}" in
    1|true|yes|on)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

set_chrome_session_restore_preferences() {
  local python_bin=""
  local preferences_file="${CHROME_USER_DATA_DIR}/Default/Preferences"

  if command -v python3 >/dev/null 2>&1; then
    python_bin="$(command -v python3)"
  elif [[ -x /lsiopy/bin/python3 ]]; then
    python_bin="/lsiopy/bin/python3"
  else
    echo "[entrypoint] python3 is unavailable, skipping session restore preference update" >&2
    return
  fi

  mkdir -p "$(dirname "${preferences_file}")"

  "${python_bin}" - "${preferences_file}" <<'PY'
import json
import sys
from pathlib import Path

preferences_path = Path(sys.argv[1])

data = {}
if preferences_path.exists():
    try:
        data = json.loads(preferences_path.read_text())
    except Exception:
        data = {}

session = data.setdefault("session", {})
session["restore_on_startup"] = 1
session.setdefault("startup_urls", [])

profile = data.setdefault("profile", {})
profile["exit_type"] = "Normal"
profile["exited_cleanly"] = True

preferences_path.write_text(json.dumps(data, separators=(",", ":")))
PY
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

if is_truthy "${CHROME_SESSION_RESTORE_ENABLED}"; then
  echo "[entrypoint] Session restore is enabled"

  if [[ " ${CHROME_CLI:-} " != *" --restore-last-session "* ]]; then
    export CHROME_CLI="${CHROME_CLI:-} --restore-last-session"
  fi

  set_chrome_session_restore_preferences
fi

socat "TCP-LISTEN:${CDP_PROXY_PORT},bind=${CDP_PROXY_BIND_ADDRESS},fork,reuseaddr" "TCP:${CHROME_DEBUG_ADDRESS}:${CHROME_DEBUG_PORT}" &

exec /init
