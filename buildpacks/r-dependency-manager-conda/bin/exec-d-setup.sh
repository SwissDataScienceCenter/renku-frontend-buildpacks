#!/usr/bin/env bash
set -euo pipefail

LAUNCHER_LOG() { echo "-----> [exec-d] $*"; }

CONDA_BIN=$(command -v conda 2>/dev/null || true)
if [[ -z "${CONDA_BIN}" ]]; then
  echo "ERROR: conda not found in PATH at runtime." >&2
  exit 1
fi

BUILD_ENV_NAME="${__RENKU_BUILD_ENV_NAME}"
BUILD_ENV_FILE="${__RENKU_BUILD_ENV_FILE}"
BUILD_ENV_DIR="${__RENKU_BUILD_ENV_DIR}"

RENKU_WORKING_DIR="${RENKU_WORKING_DIR:-$HOME}"
RENKU_MOUNT_DIR="${RENKU_MOUNT_DIR:-$RENKU_WORKING_DIR}"
USER_BASE="${RENKU_MOUNT_DIR}/.conda-envs"
USER_ENV_DIR="${USER_BASE}/${BUILD_ENV_NAME}"

LAUNCHER_LOG "Conda env name  : ${BUILD_ENV_NAME}"
LAUNCHER_LOG "User env dir    : ${USER_ENV_DIR}"
LAUNCHER_LOG "Build env dir   : ${BUILD_ENV_DIR:-<not found>}"
LAUNCHER_LOG "environment.yml : ${BUILD_ENV_FILE:-<not found>}"

# Ensure base directory exists
mkdir -p "${USER_BASE}"

# Create or sync the user-writable environment
if [[ ! -d "${USER_ENV_DIR}" ]]; then
  LAUNCHER_LOG "User env not found — setting it up …"

  if [[ -n "${BUILD_ENV_DIR}" && -d "${BUILD_ENV_DIR}" ]]; then
    LAUNCHER_LOG "Cloning build-time env (conda create --clone) …"
    conda create \
      --prefix "${USER_ENV_DIR}" \
      --clone "${BUILD_ENV_DIR}" \
      --quiet
    LAUNCHER_LOG "Clone complete."
  elif [[ -n "${LAYER_ENV_YML}" && -f "${LAYER_ENV_YML}" ]]; then
    LAUNCHER_LOG "Build-time env not available; installing from environment.yml …"
    conda env create \
      --prefix "${USER_ENV_DIR}" \
      --file "${LAYER_ENV_YML}"
    LAUNCHER_LOG "Install complete."
  else
    LAUNCHER_LOG "WARNING: Neither build env nor environment.yml found; skipping env setup."
  fi
else
  LAUNCHER_LOG "User env exists — syncing with environment.yml …"
  if [[ -n "${LAYER_ENV_YML}" && -f "${LAYER_ENV_YML}" ]]; then
    conda env update \
      --prefix "${USER_ENV_DIR}" \
      --file "${LAYER_ENV_YML}" \
      --quiet
    LAUNCHER_LOG "Sync complete."
  else
    LAUNCHER_LOG "WARNING: No environment.yml found; skipping sync."
  fi
fi

# Where should conda look for envs
# Remove the buildpack layer environment here because the names are the same and it is not writable
# Stuff written to FD3 in toml format gets converted to env variables
cat >&3 <<EOF
CONDA_ENVS_PATH = "${USER_BASE}"
R_HOME = "${USER_ENV_DIR}"
PATH = "${USER_ENV_DIR}/bin:${PATH}"
LD_LIBRARY_PATH = "${USER_ENV_DIR}/lib:${LD_LIBRARY_PATH}"
EOF

conda init
set +u
# Bashrc refernces env variables that do not exist so with set in this script,
# the source command fails.
source ~/.bashrc
set -u
conda activate "$USER_ENV_DIR"

conda config --remove channels defaults
conda config --add channels conda-forge
conda config --add channels nodefaults
conda config --set channel_priority strict

if ! grep -qE "^conda activate" ~/.bashrc; then
  echo "Adding conda activate $USER_ENV_DIR command to bashrc"
  echo "" >>~/.bashrc
  echo "conda activate $USER_ENV_DIR" >>~/.bashrc
fi
