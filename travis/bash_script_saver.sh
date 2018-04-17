#!/bin/bash

# Workaround for https://github.com/travis-ci/travis-ci/issues/6307, which
# caused the following error on MacOS X workers:
#
# Warning, RVM 1.26.0 introduces signed releases and automated check of signatures when GPG software found.
# /Users/travis/build.sh: line 109: shell_session_update: command not found
#
# The above issue is present when running scripts, e.g. using `set -e`, on OSX.
# This script should be run before other scripts to allow stable
# script execution on OSX.
#

if [[ "$TRAVIS_OS_NAME" == "osx" ]]; then
source "$( dirname "${BASH_SOURCE[0]}" )"/setup_rvm.sh;
fi
