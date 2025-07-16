#!/usr/bin/env bash
set -eo pipefail

#ensure bashrc is sourced
# shellcheck source=/dev/null
source "${HOME}"/.bashrc

RENKU_SESSION_PORT="${RENKU_SESSION_PORT:-8888}"
RENKU_WORKING_DIR="${RENKU_WORKING_DIR:-${HOME}}"
RENKU_BASE_URL_PATH="${RENKU_BASE_URL_PATH:-/}"

ttyd --cwd "${RENKU_WORKING_DIR}" --port "${RENKU_SESSION_PORT}" --base-path "${RENKU_BASE_URL_PATH}" --writable bash
