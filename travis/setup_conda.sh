#!/bin/bash

# Note to the future: keep the conda scripts separate for each OS because many
# packages call ci-helpers with:
#
#   source ci-helpers/travis/setup_conda_$TRAVIS_OS_NAME.sh
#
# The present script was added later.


# We first check if any of the custom tags are used to skip the build

TR_SKIP="\[(skip travis|travis skip)\]"
DOCS_ONLY="\[docs only|build docs\]"

# Skip build if the commit message contains [skip travis] or [travis skip]
# Remove workaround once travis has this feature natively
# https://github.com/travis-ci/travis-ci/issues/5032
if [[ ! -z $(echo $TRAVIS_COMMIT_MESSAGE | grep -E $TR_SKIP) ]]; then
    echo "Travis was requested to be skipped by the commit message, exiting."
    travis_terminate 0
elif [[ ! -z $(echo $TRAVIS_COMMIT_MESSAGE | grep -E $DOCS_ONLY) ]]; then
    if [[ $SETUP_CMD != *build_docs* ]] || [[ $SETUP_CMD != *build_sphinx* ]]; then
        echo "Only docs build was requested by the commit message, exiting."
        travis_terminate 0
    fi
fi

source ci-helpers/travis/setup_conda_$TRAVIS_OS_NAME.sh;
