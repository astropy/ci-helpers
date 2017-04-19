#!/bin/bash

# Note to the future: keep the conda scripts separate for each OS because many
# packages call ci-helpers with:
#
#   source ci-helpers/travis/setup_conda_$TRAVIS_OS_NAME.sh
#
# The present script was added later.

# Skip build if the commit message contains [skip travis] or [travis skip]
# Remove workaround once travis has this feature natively
# https://github.com/travis-ci/travis-ci/issues/5032
echo "$TRAVIS_COMMIT_MESSAGE" | grep -E  '\[(skip travis|travis skip)\]' \
    && echo "[skip travis] has been found, exiting." && exit 0

source ci-helpers/travis/setup_conda_$TRAVIS_OS_NAME.sh;
