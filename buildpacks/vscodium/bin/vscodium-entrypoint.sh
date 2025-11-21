#!/usr/bin/env bash
set -eo pipefail

#ensure bashrc is sourced
# shellcheck source=/dev/null
source "${HOME}"/.bashrc

RENKU_SESSION_PORT="${RENKU_SESSION_PORT:-8888}"
RENKU_WORKING_DIR="${RENKU_WORKING_DIR:-${HOME}}"
RENKU_BASE_URL_PATH="${RENKU_BASE_URL_PATH:-/}"

codium-server \
  --server-base-path "${RENKU_BASE_URL_PATH%/}" \
  --host "${RENKU_SESSION_IP}" \
  --port "${RENKU_SESSION_PORT}" \
  --extensions-dir "${RENKU_MOUNT_DIR}/.vscode/extensions" \
  --server-data-dir "${RENKU_MOUNT_DIR}/.vscode" \
  --without-connection-token \
  --accept-server-license-terms \
  --telemetry-level off \
  --default-folder "${RENKU_WORKING_DIR}"
