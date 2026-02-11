#!/usr/bin/env bash
set -eo pipefail

export RENV_PATHS_ROOT="${RENKU_MOUNT_DIR}/.rstudio/cache:${RENV_PATHS_ROOT}"
export ORIGINAL_LOCKFILE="/workspace/renv.lock"

# shellcheck disable=SC2016
current_r_version=$(Rscript --vanilla -e 'cat(paste(R.version$major, R.version$minor, sep="."))' 2>/dev/null)

# Check for version mismatch - clean library but preserve cache
if [ -f "${RENKU_MOUNT_DIR}/renv.lock" ]; then
    stored_r_version=$(jq -r ".R.Version" "${RENKU_MOUNT_DIR}/renv.lock")
    if [ "${stored_r_version}" != "${current_r_version}" ]; then
        echo "R version mismatch (${stored_r_version} -> ${current_r_version}) - rebuilding library..."
        rm -rf "${RENKU_MOUNT_DIR}/renv"
        rm -f "${RENKU_MOUNT_DIR}/renv.lock"
    fi
fi


# Restore if needed
if [ ! -f "${RENKU_MOUNT_DIR}/renv.lock" ]; then
    echo "Restoring renv environment from ${ORIGINAL_LOCKFILE}..."

    cd "${RENKU_MOUNT_DIR}"
    R --silent --no-init-file -e 'renv::activate()'
    R --silent -e 'renv::restore(lockfile = Sys.getenv("ORIGINAL_LOCKFILE"), prompt = FALSE)'
    # shellcheck disable=SC2016
    R --silent -e 'deps <- renv::dependencies()
        installed_pkgs <- installed.packages()[, "Package"]
        required_pkgs <- unique(deps$Package)
        missing_pkgs <- required_pkgs[!(required_pkgs %in% installed_pkgs)]
        if (length(missing_pkgs) > 0) {
          cat("Installing missing packages:\n")
          print(missing_pkgs)
          renv::install(missing_pkgs)
        }
        renv::snapshot()' || true

    echo "renv restore complete."
fi
