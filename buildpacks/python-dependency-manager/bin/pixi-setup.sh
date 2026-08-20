#!/usr/bin/env bash
set -uo pipefail

warn() { echo "Renku: $*" >&2; }

mount="${RENKU_MOUNT_DIR:-}"
work="${RENKU_WORKING_DIR:-${mount:-$PWD}}"
env_name="${BP_PIXI_ENVIRONMENT_NAME:-default}"
cache_src="${RENKU_PIXI_CACHE_DIR:-}"
project_name="${RENKU_PIXI_PROJECT_NAME:-}"

if [ -z "$mount" ] || ! mkdir -p "$mount" 2>/dev/null || [ ! -w "$mount" ]; then
    warn "no writable mount; using the environment baked in at build time"
    exit 0
fi

exec 9>"$mount/.setup.lock"
if ! flock -w 300 9; then
    warn "timed out waiting for .setup.lock; continuing without setup"
    exit 0
fi

mkdir -p "$mount/.pixi" "$mount/.pixi_cache"
printf 'PIXI_CACHE_DIR = "%s/.pixi_cache"\n' "$mount" >&3

if [ -n "$cache_src" ] && [ -d "$cache_src" ]; then
    cp -ras --update=none "$cache_src/." "$mount/.pixi_cache" 2>/dev/null || warn "failed to seed pixi cache"
fi

project_dir=""
if [ -n "$project_name" ]; then
    for candidate in "$work/pixi.toml" "$work/pyproject.toml" "$work"/*/pixi.toml "$work"/*/pyproject.toml; do
        [ -r "$candidate" ] || continue
        case "$candidate" in
            */pyproject.toml) grep -q '\[tool\.pixi' "$candidate" || continue ;;
        esac
        candidate_name="$(grep -m1 '^name = ' "$candidate" | sed 's/^name = "\(.*\)"$/\1/')"
        if [ "$candidate_name" = "$project_name" ]; then
            project_dir="$(dirname "$candidate")"
            break
        fi
    done
fi

if [ -z "$project_dir" ]; then
    warn "could not find a pixi project named '$project_name' in $work"
    warn "pixi cache seeded; run 'cd <your-project> && pixi install' to set up the env"
    exit 0
fi

printf 'PATH = "%s/.pixi/envs/%s/bin:%s"\n' "$project_dir" "$env_name" "$PATH" >&3

cd "$project_dir" || { warn "cannot cd to $project_dir"; exit 0; }

mkdir -p "$project_dir/.pixi" 2>/dev/null
if [ ! -w "$project_dir/.pixi" ]; then
    warn "pixi project at $project_dir is not writable; using build-time env"
    exit 0
fi

pixi install --environment "$env_name" || { warn "pixi install failed; using build-time env"; exit 0; }
pixi shell-hook --environment "$env_name" > "$project_dir/.pixi/activation.sh" || { warn "pixi shell-hook failed"; exit 0; }

if ! grep -qF "source $project_dir/.pixi/activation.sh" "${HOME}/.bashrc" 2>/dev/null; then
    printf "source %s/.pixi/activation.sh\n" "$project_dir" >> "${HOME}/.bashrc" || warn "failed to update .bashrc"
fi

# shellcheck source=/dev/null
source "$project_dir/.pixi/activation.sh" || warn "failed to source activation script"
