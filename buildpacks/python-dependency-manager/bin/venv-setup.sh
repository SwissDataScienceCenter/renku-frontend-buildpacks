#!/usr/bin/env bash
set -uo pipefail

warn() { echo "Renku: $*" >&2; }
bashrc_add() { grep -qF -- "$1" "$HOME/.bashrc" 2>/dev/null || printf '%s\n' "$1" >> "$HOME/.bashrc"; }

mount="${RENKU_MOUNT_DIR:-}"
work="${RENKU_WORKING_DIR:-${mount:-$PWD}}"

if [ -z "$mount" ] || ! mkdir -p "$mount" 2>/dev/null || [ ! -w "$mount" ]; then
    warn "no writable mount; using the environment baked in at build time"
    exit 0
fi

exec 9>"$mount/.setup.lock"
if ! flock -w 300 9; then
    warn "timed out waiting for .setup.lock; continuing without setup"
    exit 0
fi

venv_dir="$work/.venv"
venv_version="$(grep "version = " "$venv_dir/pyvenv.cfg" 2>/dev/null | cut -d' ' -f3)"
base_version="$(python --version 2>/dev/null | cut -d' ' -f2)"
if [ -d "$venv_dir" ] && [ "$venv_version" != "$base_version" ]; then
    echo "Virtualenv exists but has version mismatch - recreating..."
    rm -rf "$venv_dir"
fi

python -m venv --system-site-packages "$venv_dir"
base_site_packages="$(python -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')"
derived_site_packages="$("$venv_dir/bin/python" -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')"
echo "$base_site_packages" > "$derived_site_packages/_base_packages.pth"

bashrc_add "source $venv_dir/bin/activate"

# shellcheck source=/dev/null
source "$venv_dir/bin/activate"

if python -c "import ipykernel" >/dev/null 2>&1; then
    JUPYTER_DATA_DIR="$mount/.local/share/jupyter/" \
        python -m ipykernel install --user --name Python3 || warn "ipykernel install failed"
fi

uv_cache_src="${RENKU_UV_CACHE_DIR:-}"
if [ -n "$uv_cache_src" ] && [ -d "$uv_cache_src" ]; then
    mkdir -p "$mount/.uv_cache"
    cp -ras --update=none "$uv_cache_src/." "$mount/.uv_cache" 2>/dev/null || warn "failed to seed uv cache"
    printf 'UV_CACHE_DIR = "%s/.uv_cache"\n' "$mount" >&3
    bashrc_add "export UV_CACHE_DIR=$mount/.uv_cache"
    printf 'UV_PROJECT_ENVIRONMENT = "%s"\n' "$venv_dir" >&3
    bashrc_add "export UV_PROJECT_ENVIRONMENT=$venv_dir"
fi
