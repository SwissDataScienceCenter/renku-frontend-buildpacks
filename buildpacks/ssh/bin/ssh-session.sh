#!/bin/sh
# dropbear runs this as the forced command for every SSH session (-c). A forced
# command would otherwise also replace sftp/scp exec requests, so dispatch instead:
# SSH_ORIGINAL_COMMAND is empty for interactive logins and holds the requested
# command (or the sftp-server path dropbear selected for the sftp subsystem) otherwise.
cd "${RENKU_WORKING_DIR:-${HOME}}" 2>/dev/null || true
if [ -n "${SSH_ORIGINAL_COMMAND:-}" ]; then
  exec "${SHELL:-/bin/bash}" -c "${SSH_ORIGINAL_COMMAND}"
fi
# attach if a session exists, start a new one otherwise, so work survives disconnects.
# buildpacks export LD_LIBRARY_PATH into the launch env per the CNB spec (e.g. conda
# layer libs); those shadow the system libs distro tmux links against and crash it.
# Scrub it for the tmux binary and server only — panes still get the session env via
# -e / set-environment -g (tmux >= 3.2), so user shells keep it intact.
saved_ld_library_path="${LD_LIBRARY_PATH:-}"
unset LD_LIBRARY_PATH
if [ -n "${saved_ld_library_path}" ] && tmux has-session 2>/dev/null; then
  tmux set-environment -g LD_LIBRARY_PATH "${saved_ld_library_path}"
fi
exec tmux new -A -e LD_LIBRARY_PATH="${saved_ld_library_path}"
