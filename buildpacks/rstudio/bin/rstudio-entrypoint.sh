#!/usr/bin/env bash
set -eo pipefail

mkdir -p "${RENKU_MOUNT_DIR}/.rstudio"

cat > "${RENKU_MOUNT_DIR}/.rstudio/rsession.sh" <<EOF
#!/usr/bin/env bash
export RENV_PATHS_ROOT="${RENKU_MOUNT_DIR}/.rstudio/cache:${RENV_PATHS_ROOT}"
export RENV_PATHS_SANDBOX="${RENKU_MOUNT_DIR}/.rstudio/cache/renv/sandbox"
export R_INTERACTIVE_DEVICE="${R_INTERACTIVE_DEVICE:-pdf}"
export RENV_CONFIG_INSTALL_STAGED=FALSE
export RENV_CONFIG_UPDATES_CHECK=FALSE
export R_LIBS_SITE="${RENKU_MOUNT_DIR}/.rstudio/libs:${R_LIBS_SITE}"
exec rsession "\$@"
EOF
chmod u+x "${RENKU_MOUNT_DIR}/.rstudio/rsession.sh"

cat > "${RENKU_MOUNT_DIR}/.rstudio/rserver.conf" <<EOF
database-config-file=${RENKU_MOUNT_DIR}/.rstudio/db.conf
www-frame-origin=same
www-port=${RENKU_SESSION_PORT}
www-address=0.0.0.0
server-data-dir=${RENKU_MOUNT_DIR}/.rstudio/data
auth-none=1
www-verify-user-agent=0
www-root-path=${RENKU_BASE_URL_PATH}
EOF

cat >"${RENKU_MOUNT_DIR}/.rstudio/db.conf" <<EOL
provider=sqlite
directory=${RENKU_MOUNT_DIR}/.rstudio
EOL

cat > "${RENKU_MOUNT_DIR}/.rstudio/rsession.conf" <<EOF
session-default-working-dir=${RENKU_WORKING_DIR}
session-default-new-project-dir=${RENKU_WORKING_DIR}
EOF

if [ -z "${USER}" ]; then
	USER=$(whoami)
	# NOTE: If USER is not exported then accessing rstudio in the browser gets
	# stuck into a redirect loop and rstudio cannot be accessed.
	# See: https://forum.posit.co/t/rstudio-server-behind-ingress-proxy-missing-cookie-info/134649
	export USER
fi

mkdir -p "${RENKU_MOUNT_DIR}/.rstudio/logs"

# stderr log end up polluting the console. so we create file logs and tail them out to stderr
touch "${RENKU_MOUNT_DIR}/.rstudio/logs/rserver.log"
touch "${RENKU_MOUNT_DIR}/.rstudio/logs/rsession.log"

tail -F "${RENKU_MOUNT_DIR}/.rstudio/logs/rserver.log" &
tail -F "${RENKU_MOUNT_DIR}/.rstudio/logs/rsession.log" &

cat > "${RENKU_MOUNT_DIR}/.rstudio/logging.conf" <<EOF
[@rserver]
log-level=info
logger-type=file
log-dir=${RENKU_MOUNT_DIR}/.rstudio/logs

[@rsession]
log-level=info
logger-type=file
log-dir=${RENKU_MOUNT_DIR}/.rstudio/logs
EOF

RS_LOG_CONF_FILE="${RENKU_MOUNT_DIR}/.rstudio/logging.conf" rserver \
    --rsession-path="${RENKU_MOUNT_DIR}/.rstudio/rsession.sh" \
    --config-file="${RENKU_MOUNT_DIR}/.rstudio/rserver.conf" \
    --rsession-config-file="${RENKU_MOUNT_DIR}/.rstudio/rsession.conf" \
    --server-user="${USER}" \
    --server-daemonize=0
