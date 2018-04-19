#!/bin/bash

# Workaround for executing scripts on OSX.
#
# Workaround for https://github.com/travis-ci/travis-ci/issues/6307, which
# caused the following error on MacOS X workers:
#
# Warning, RVM 1.26.0 introduces signed releases and automated check of signatures when GPG software found.
# /Users/travis/build.sh: line 109: shell_session_update: command not found
#
# The above issue is present when running scripts using `set -e` on OSX.
# This script should therefore be run 1st and by default to allow stable
# script execution on OSX.

source "$( dirname "${BASH_SOURCE[0]}" )"/setup_rvm_osx.sh
