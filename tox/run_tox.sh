#!/bin/bash

# This script installs and runs tox, assuming that the following environment
# variables are defined:
#
# * PYTHON: the Python interpreter to use (defaults to 'python')
# * TOXENV: the name of the tox environment to run
# * TOXARGS: the arguments to pass to tox
# * TOXPOSARGS: the positional arguments to pass after the -- separator
#
# The resulting tox command looks like:
#
#     tox -e $TOXENV $TOXPOSARGS -- $TOXPOSARGS
#
# This script may also apply patches, for example to prevent a too recent
# version of pytest from being installed, or excluding a broken version of
# another package. This is done by running a proxy PyPI server which
# excludes the problematic package versions.

set -e

if [ -z "$PYTHON" ]; then
  PYTHON=python;
fi

echo '########################################################################'
echo ''
echo 'ci-helpers run_tox.sh script'
echo ''
echo 'PYTHON='$PYTHON
echo 'TOXENV='$TOXENV
echo 'TOXARGS='$TOXARGS
echo 'TOXPOSARGS='$TOXPOSARGS
echo ''

# Temporary version limitation, remove here and below once
# https://github.com/astropy/pytest-doctestplus/issues/94 is fixed and released

# echo 'No global patches being applied'
echo 'Patching pytest to <5.4'

echo ''
echo 'Installing tox:'
echo ''

# Start off by installing tox
$PYTHON -m pip install tox

# Ensure pip and setuptools are recent (we don't force upgrade to the
# absolute most recent version since this is not necessary)
$PYTHON -m pip install "pip>=19.3.1" "setuptools>=30.3.0"

# If PyPI patches are needed, uncommend the following line
$PYTHON -m pip install tox-pypi-filter

echo ''
echo 'Listing Python packages:'
echo ''

# List the current installed packages
$PYTHON -m pip freeze

echo ''
echo 'Running tox:'
echo ''

# Run tox. If PyPI patches are needed, add a --pypi-filter=...
# option to the command, e.g. --pypi-filter='pytest<5'
$PYTHON -m tox -e $TOXENV $TOXARGS --pypi-filter='pytest<5.4' -- $TOXPOSARGS
echo ''
echo '########################################################################'
