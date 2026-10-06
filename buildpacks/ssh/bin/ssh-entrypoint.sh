#!/usr/bin/env bash
set -eo pipefail

# ensure bashrc is sourced
# shellcheck source=/dev/null
source "${HOME}"/.bashrc

# host key on the mounted project dir so it survives session restarts
DROPBEAR_HOST_KEY="${RENKU_MOUNT_DIR}/.ssh/dropbear_ed25519_host_key"

ssh_bin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "${DROPBEAR_HOST_KEY}" ]]; then
  mkdir -p "$(dirname "${DROPBEAR_HOST_KEY}")"
  "${ssh_bin_dir}/dropbearkey" -t ed25519 -f "${DROPBEAR_HOST_KEY}" >/dev/null
fi

# accept only the proxy's proxy-to-session public key (mounted by data-services)
PROXY_AUTH_PUB="${RENKU_MOUNT_DIR}/.ssh/proxy_auth_key.pub"
if [[ -f "${PROXY_AUTH_PUB}" ]]; then
  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"
  cp "${PROXY_AUTH_PUB}" "${HOME}/.ssh/authorized_keys"
  chmod 600 "${HOME}/.ssh/authorized_keys"
fi

if [[ ! -s "${HOME}/.ssh/authorized_keys" ]]; then
  echo "WARNING: no usable SSH authorized keys in ${HOME}/.ssh/authorized_keys (source: ${PROXY_AUTH_PUB}); all SSH logins will be rejected" >&2
fi

# -s: public key auth only (password logins disabled)
# -e: pass the launcher-provided environment (CNB launch env) to SSH sessions
# -c: run every session through ssh-session.sh (tmux for logins, passthrough for
#     exec requests and the sftp subsystem)
exec "${ssh_bin_dir}/dropbear" -F -e -c "${ssh_bin_dir}/ssh-session.sh" -r "${DROPBEAR_HOST_KEY}" -s -p "${RENKU_SESSION_PORT:-8000}"
