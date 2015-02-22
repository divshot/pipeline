#!/usr/bin/env bash

set -e

echo $BUILDKITE_BUILD_FOLDER_NAME
/home/build/npm/bin/divshot push ${DIVSHOT_ENV:-development} --app $DIVSHOT_APP --token $DIVSHOT_TOKEN