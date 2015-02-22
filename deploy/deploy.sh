#!/usr/bin/env bash

set -e

echo $BUILDKITE_BUILD_FOLDER_NAME
ls /builds/$BUILDKITE_BUILD_FOLDER_NAME
cd /builds/$BUILDKITE_BUILD_FOLDER_NAME
divshot push ${DIVSHOT_ENV:-development} --app $DIVSHOT_APP --token $DIVSHOT_TOKEN