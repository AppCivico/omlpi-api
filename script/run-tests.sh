#!/bin/bash -e
source $HOME/perl5/perlbrew/etc/bashrc

mkdir -p /data/log/;

cd /src;

if [ -f envfile_local.sh ]; then
    source envfile_local.sh
else
    source envfile.sh
fi

cpanm -n . --installdeps
sqitch deploy -t $SQITCH_DEPLOY

rm -f /src/test-logs/*
yath test -It/lib  -PAndi::Preload --no-color -j 18 -T -L


