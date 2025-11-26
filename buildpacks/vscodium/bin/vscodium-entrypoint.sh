#!/usr/bin/env bash
set -eo pipefail

#ensure bashrc is sourced
# shellcheck source=/dev/null
source "${HOME}"/.bashrc

RENKU_SESSION_PORT="${RENKU_SESSION_PORT:-8888}"
RENKU_WORKING_DIR="${RENKU_WORKING_DIR:-${HOME}}"
RENKU_BASE_URL_PATH="${RENKU_BASE_URL_PATH:-/}"

VSCODIUM_DATA_DIR="${RENKU_MOUNT_DIR}/.vscode"
mkdir -p "${VSCODIUM_DATA_DIR}/extensions" || VSCODIUM_DATA_DIR="${RENKU_MOUNT_DIR}/.vscode_"

codium-server \
  --server-base-path "${RENKU_BASE_URL_PATH%/}" \
  --host "${RENKU_SESSION_IP}" \
  --port "${RENKU_SESSION_PORT}" \
  --extensions-dir "${VSCODIUM_DATA_DIR}/extensions" \
  --server-data-dir "${VSCODIUM_DATA_DIR}" \
  --without-connection-token \
  --accept-server-license-terms \
  --telemetry-level off \
  --default-folder "${RENKU_WORKING_DIR}"
