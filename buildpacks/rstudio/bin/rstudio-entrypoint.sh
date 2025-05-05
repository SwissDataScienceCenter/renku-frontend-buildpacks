#!/usr/bin/env bash
set -eo pipefail

mkdir -p "$RENKU_MOUNT_DIR/.rstudio"

cat >"$RENKU_MOUNT_DIR/.rstudio/rstudio.conf" <<EOL
database-config-file=$RENKU_MOUNT_DIR/.rstudio/db.conf
www-frame-origin=same
EOL
cat >"$RENKU_MOUNT_DIR/.rstudio/db.conf" <<EOL
provider=sqlite
directory=$RENKU_MOUNT_DIR/.rstudio
EOL

if [ -z "$USER" ]; then
	USER=$(whoami)
	# NOTE: If USER is not exported then accessing rstudio in the browser gets
	# stuck into a redirect loop and rstudio cannot be accessed.
	# See: https://forum.posit.co/t/rstudio-server-behind-ingress-proxy-missing-cookie-info/134649
	export USER
fi

RS_LOGGER_TYPE=stderr RS_LOG_LEVEL=debug rserver \
	--www-port="$RENKU_SESSION_PORT" \
	--www-address=0.0.0.0 \
	--server-user="$USER" \
	--server-working-dir="$RENKU_WORKING_DIR" \
	--server-data-dir="$RENKU_MOUNT_DIR/.rstudio" \
	--server-daemonize=0 \
	--config-file="$RENKU_MOUNT_DIR/.rstudio/rstudio.conf" \
	--auth-none=1 \
	--www-verify-user-agent=0 \
	--www-root-path="$RENKU_BASE_URL_PATH"
