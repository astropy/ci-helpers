#!/bin/bash

# Skip build if the commit message contains [skip travis] or [travis skip]
# Remove workaround once travis has this feature natively
# https://github.com/travis-ci/travis-ci/issues/5032
echo "$TRAVIS_COMMIT_MESSAGE" | grep -E  '\[(skip travis|travis skip)\]' \
    && echo "[skip travis] has been found, exiting." && exit 0

if [[ $DEBUG == True ]]; then
    set -x
fi

# Workaround for https://github.com/travis-ci/travis-ci/issues/6307, which
# caused the following error on MacOS X workers:
#
# /Users/travis/build.sh: line 109: shell_session_update: command not found
#
rvm get head

echo "==================== Starting executing ci-helpers scripts ====================="

# Install conda
# http://conda.pydata.org/docs/travis.html#the-travis-yml-file
wget https://repo.continuum.io/miniconda/Miniconda3-latest-MacOSX-x86_64.sh -O miniconda.sh
bash miniconda.sh -b -p $HOME/miniconda
export PATH="$HOME/miniconda/bin:$PATH"

# Install common Python dependencies
source "$( dirname "${BASH_SOURCE[0]}" )"/setup_dependencies_common.sh

echo "================= Returning executing local .travis.yml script ================="
