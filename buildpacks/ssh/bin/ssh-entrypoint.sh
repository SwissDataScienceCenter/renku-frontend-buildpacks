#!/usr/bin/env bash
set -eo pipefail

# ensure bashrc is sourced
# shellcheck source=/dev/null
source "${HOME}"/.bashrc

SSH_PORT=2222
# host key on the mounted project dir so it survives session restarts
DROPBEAR_HOST_KEY="${RENKU_MOUNT_DIR}/.ssh/dropbear_ed25519_host_key"

ssh_bin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ssh_www_dir="$(dirname "${ssh_bin_dir}")/www"

if [[ ! -f "${DROPBEAR_HOST_KEY}" ]]; then
  mkdir -p "$(dirname "${DROPBEAR_HOST_KEY}")"
  "${ssh_bin_dir}/dropbearkey" -t ed25519 -f "${DROPBEAR_HOST_KEY}" >/dev/null
fi

# -s: public key auth only (password logins disabled)
# -e: pass the launcher-provided environment (CNB launch env) to SSH sessions
# -c: run every session through ssh-session.sh (tmux for logins, passthrough for
#     exec requests and the sftp subsystem)
# web placeholder page in background; dropbear stays in foreground for tini
"${ssh_bin_dir}/darkhttpd" "${ssh_www_dir}" --port "${RENKU_SESSION_PORT:-8000}" &
exec "${ssh_bin_dir}/dropbear" -F -e -c "${ssh_bin_dir}/ssh-session.sh" -r "${DROPBEAR_HOST_KEY}" -s -p "${SSH_PORT}"
