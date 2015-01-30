#!/bin/env sh

export HOME=/home/build
export PATH=$PATH:$HOME/npm/bin

set -e
npm install
if [ -a bower.json ]; then bower install; fi
npm run build