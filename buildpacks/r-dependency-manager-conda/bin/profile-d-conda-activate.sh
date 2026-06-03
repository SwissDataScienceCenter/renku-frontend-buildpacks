# Injected by sdsc/conda buildpack
# Activates the user-writable conda environment if present.
# _CONDA_USER_ENV="${USER_CONDA_ENV_BASE:-${HOME}/.conda-envs}/${CONDA_ENV_NAME:-env}"
# if [[ -f "$(conda info --base 2>/dev/null)/etc/profile.d/conda.sh" ]]; then
#   # shellcheck disable=SC1091
#   source "$(conda info --base)/etc/profile.d/conda.sh"
#   if [[ -d "${_CONDA_USER_ENV}" ]]; then
#     conda activate "${_CONDA_USER_ENV}" 2>/dev/null || true
#   fi
# fi
# unset _CONDA_USER_ENV
echo "Running profile.d activate"
