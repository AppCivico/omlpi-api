#!/bin/sh

export OMLPI_API_LOG_DIR=/data/log/
mkdir -p /data/log/;
chown -R app:app /data/log/

exec /sbin/setuser app /src/script/start-server.sh

