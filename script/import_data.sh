#!/bin/bash -e
source $HOME/perl5/perlbrew/etc/bashrc

cd /src;

if [ -f envfile_local.sh ]; then
    source envfile_local.sh
else
    source envfile.sh
fi

cpanm -n . --installdeps
perl script/import_data.pl