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
# the conda layer's LD_LIBRARY_PATH shadows system libs 
unset LD_LIBRARY_PATH
tmux attach || exec tmux
