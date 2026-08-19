#!/usr/bin/env bash
set -uo pipefail

warn() { echo "Renku: $*" >&2; }

mount="${RENKU_MOUNT_DIR:-}"

# The python-dependency-manager pixi setup runs first (buildpack build order
# governs exec.d execution) and only writes the activation script when the
# mutable pixi env was installed successfully. No file = no kernel.
activation="${mount}/.pixi/activation.sh"
[ -f "$activation" ] || exit 0

# shellcheck disable=SC1090 source=/dev/null
source "$activation" || { warn "failed to source pixi activation script"; exit 0; }

if ! python -c "import ipykernel" >/dev/null 2>&1; then
    python -m ensurepip --upgrade >/dev/null 2>&1 \
        || { warn "ensurepip failed; skipping kernel install"; exit 0; }
    python -m pip install --quiet ipykernel >/dev/null 2>&1 \
        || { warn "pip install ipykernel failed; skipping kernel install"; exit 0; }
fi

JUPYTER_DATA_DIR="$mount/.local/share/jupyter/" \
    python -m ipykernel install --user --name Python3 \
    || warn "ipykernel install failed"
