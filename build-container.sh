#!/bin/bash -e
cp Makefile.PL docker/Makefile_local.PL
cp -R crontab docker/

docker build -t appcivico/andi_api docker/
