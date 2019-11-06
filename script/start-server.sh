#!/bin/bash -e
source /home/app/perl5/perlbrew/etc/bashrc

mkdir -p /data/log/;

export ANDI_API_LOG_DIR=/data/log/

cd /src;
if [ -f envfile_local.sh ]; then
    source envfile_local.sh
else
    source envfile.sh
fi

export SQITCH_DEPLOY=${SQITCH_DEPLOY:=docker}

cpanm -nv . --installdeps
sqitch deploy -t $SQITCH_DEPLOY

MOJO_IOLOOP_DEBUG=1 hypnotoad script/andi-api

sleep infinity