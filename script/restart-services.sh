#!/bin/bash -e
cd /src;
source /home/app/perl5/perlbrew/etc/bashrc;

if [ -f envfile_local.sh ]; then
    source envfile_local.sh
else
    source envfile.sh
fi

export SQITCH_DEPLOY=${SQITCH_DEPLOY:=docker}

cpanm -nv . --installdeps
sqitch deploy -t $SQITCH_DEPLOY

LIBEV_FLAGS=4 hypnotoad script/andi-api
pgrep -f 'minion worker$' | xargs kill -INT
