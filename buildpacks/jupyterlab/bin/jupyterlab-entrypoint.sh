#!/usr/bin/env bash
set -eo pipefail

#ensure bashrc is sourced
# shellcheck source=/dev/null
source "${HOME}"/.bashrc

JUPYTER_ENV_DIR=$1

if [ -z "$JUPYTER_ENV_DIR" ]; then
	echo "WARNING: Running with JUPYTER_ENV_DIR not set at all, this means python and jupyter executables are expected at /bin/."
fi

if [ -n "$RENKU_WORKING_DIR" ]; then
	if [ ! -d "$RENKU_WORKING_DIR" ]; then
		mkdir -p "$RENKU_WORKING_DIR"
	fi
	# This allows the terminal in jupyterlab to open in the working directory
	cd "$RENKU_WORKING_DIR"
	# The ServerApp.root_dir further below only changes the file browser location in the Jupyter UI
fi

if [ -n "$RENKU_MOUNT_DIR" ]; then
	# This sets the data dir for Jupyter
	export JUPYTER_DATA_DIR="${RENKU_MOUNT_DIR}/.local/share/jupyter/"
	# # This sets the path for --user pip installs
	export PYTHONUSERBASE="${RENKU_MOUNT_DIR}/.local"
fi

"${JUPYTER_ENV_DIR}/bin/python" -E "${JUPYTER_ENV_DIR}/bin/jupyter-lab" \
	--ip "${RENKU_SESSION_IP}" \
	--port "${RENKU_SESSION_PORT}" \
	--ServerApp.base_url "$RENKU_BASE_URL_PATH" \
	--IdentityProvider.token "" \
	--ServerApp.password "" \
	--ServerApp.allow_remote_access true \
	--ContentsManager.allow_hidden true \
	--ServerApp.root_dir "${RENKU_WORKING_DIR}" \
	--KernelSpecManager.ensure_native_kernel False
