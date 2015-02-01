#!/bin/env sh

chown -R build:build /home/build/scripts
sudo -E -u build bash /home/build/scripts/build.sh