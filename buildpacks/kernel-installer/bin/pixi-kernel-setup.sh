#!/usr/bin/env bash
set -uo pipefail

warn() { echo "Renku: $*" >&2; }

# The python-dependency-manager pixi setup runs first (buildpack build order
# governs exec.d execution) and appends the pixi activation to ~/.bashrc only
# when the mutable env was installed successfully. Sourcing .bashrc picks up
# the env without needing to know where the project lives.
set +u
# shellcheck disable=SC1090 source=/dev/null
source "${HOME}/.bashrc" >/dev/null 2>&1 || warn "failed to source .bashrc"
set -u

# No active pixi env (launch setup failed or skipped) = no kernel.
case "$(command -v python 2>/dev/null)" in
    */.pixi/envs/*) ;;
    *) exit 0 ;;
esac

if ! python -c "import ipykernel" >/dev/null 2>&1; then
    python -m ensurepip --upgrade >/dev/null 2>&1 \
        || { warn "ensurepip failed; skipping kernel install"; exit 0; }
    python -m pip install --quiet ipykernel >/dev/null 2>&1 \
        || { warn "pip install ipykernel failed; skipping kernel install"; exit 0; }
fi

JUPYTER_DATA_DIR="${RENKU_MOUNT_DIR:-$HOME}/.local/share/jupyter/" \
    python -m ipykernel install --user --name Python3 \
    || warn "ipykernel install failed"
