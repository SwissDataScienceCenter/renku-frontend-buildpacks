#!/usr/bin/env bash
set -eo pipefail

# ensure bashrc is sourced (this is presumably where the .venv gets activated)
# shellcheck source=/dev/null
source "${HOME}"/.bashrc

# The venv that will be activated for pip/uv installs. marimo is one of its deps.
# Prefer the explicitly activated venv; fall back to the known mount path.
VENV_DIR="${VIRTUAL_ENV:-${RENKU_MOUNT_DIR}/.venv}"

if [ ! -x "${VENV_DIR}/bin/python" ]; then
	echo "ERROR: No python found in ${VENV_DIR}. Is the .venv created/activated?" >&2
	exit 1
fi

cd "${RENKU_WORKING_DIR}"
#
# Build marimo args. marimo rejects `--base-url /` because it's equivalent to
# not setting a base URL at all, so only pass the flag when it's meaningful.
marimo_args=(
	--host "${RENKU_SESSION_IP}"
	--port "${RENKU_SESSION_PORT}"
	--no-token
	--headless
	--skip-update-check
)

if [ -n "$RENKU_BASE_URL_PATH" ] && [ "$RENKU_BASE_URL_PATH" != "/" ]; then
	marimo_args+=(--base-url "${RENKU_BASE_URL_PATH}")
fi

CONFIG_FILE="${RENKU_WORKING_DIR}/.marimo.toml"

"${VENV_DIR}/bin/python" - "$CONFIG_FILE" <<'PY'
import sys, tomlkit

path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as f:
        doc = tomlkit.parse(f.read())
except FileNotFoundError:
    doc = tomlkit.document()

server = doc.get("server")
# guard against a malformed non-table value
if not isinstance(server, dict):
    server = tomlkit.table()
    doc["server"] = server

server["follow_symlink"] = True

with open(path, "w", encoding="utf-8") as f:
    f.write(tomlkit.dumps(doc))
PY

"${VENV_DIR}/bin/python3" -m marimo edit "${marimo_args[@]}" "${RENKU_WORKING_DIR}"
