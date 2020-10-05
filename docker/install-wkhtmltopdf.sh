#!/bin/bash -xe
cd /tmp
curl -LO 'https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.xenial_amd64.deb'
dpkg -i wkhtmltox_0.12.6-1.xenial_amd64.deb
