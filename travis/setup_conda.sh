#!/bin/bash

# Note to the future: keep the conda scripts separate for each OS because many
# packages call ci-helpers with:
# 
#   source ci-helpers/travis/setup_conda_$TRAVIS_OS_NAME.sh
#
# The present script was added later.

source ci-helpers/travis/setup_conda_$TRAVIS_OS_NAME.sh;
