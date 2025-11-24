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

# if [ -n "$RENKU_MOUNT_DIR" ]; then
# 	if [ ! -d "$RENKU_MOUNT_DIR" ]; then
# 		mkdir -p "$RENKU_MOUNT_DIR"
# 	fi
# 	mkdir -p "$RENKU_MOUNT_DIR/.jupyterlab_pip"
# 	# This tells pip to install packages in "$RENKU_MOUNT_DIR/.jupyterlab_pip"
# 	export PIP_TARGET="$RENKU_MOUNT_DIR/.jupyterlab_pip"
# fi

# if [ -d "${RENKU_MOUNT_DIR}/.jupyterlab_venv" ] && \
#    [ "$(grep "version = " ${RENKU_MOUNT_DIR}/.jupyterlab_venv/pyvenv.cfg 2>/dev/null | cut -d' ' -f3)" != "$("${JUPYTER_ENV_DIR}/bin/python" --version 2>/dev/null | cut -d' ' -f2)" ]; then
#     echo "Virtualenv exists but has mismatch - recreating..."
#     rm -rf ${RENKU_MOUNT_DIR}/.jupyterlab_venv
# fi
# "${JUPYTER_ENV_DIR}/bin/python" -m venv --system-site-packages "${RENKU_MOUNT_DIR}/.jupyterlab_venv"
# base_site_packages="$("${JUPYTER_ENV_DIR}/bin/python" -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')"
# derived_site_packages="$("${RENKU_MOUNT_DIR}/.jupyterlab_venv/bin/python" -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')"
# echo "$base_site_packages" > "$derived_site_packages"/_base_packages.pth
# source ${RENKU_MOUNT_DIR}/.jupyterlab_venv/bin/activate

# "${RENKU_MOUNT_DIR}/.jupyterlab_venv/bin/python" -E "${JUPYTER_ENV_DIR}/bin/jupyter-lab" \
# 	--ip "${RENKU_SESSION_IP}" \
# 	--port "${RENKU_SESSION_PORT}" \
# 	--ServerApp.base_url "$RENKU_BASE_URL_PATH" \
# 	--IdentityProvider.token "" \
# 	--ServerApp.password "" \
# 	--ServerApp.allow_remote_access true \
# 	--ContentsManager.allow_hidden true \
# 	--ServerApp.root_dir "${RENKU_WORKING_DIR}" \
# 	--KernelSpecManager.ensure_native_kernel False
