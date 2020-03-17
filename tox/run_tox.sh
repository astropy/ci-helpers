#!/bin/bash -xe

# This script installs and runs tox, assuming that the following environment
# variables are defined:
#
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

echo '########################################################################'
echo ''
echo 'ci-helpers run_tox.sh script'
echo ''
echo 'TOXENV='$TOXENV
echo 'TOXARGS='$TOXARGS
echo 'TOXPOSARGS='$TOXPOSARGS
echo ''
echo 'No global patches being applied'
echo ''
echo 'Installing tox:'
echo ''

# Start off by installing tox
pip install tox

# If PyPI patches are needed, uncommend the following line
pip install tox-pypi-filter

echo ''
echo 'Listing Python packages:'
echo ''

# List the current installed packages
pip freeze

echo ''
echo 'Running tox:'
echo ''

# Run tox. If PyPI patches are needed, add a --pypi-filter=...
# option to the command, e.g. --pypi-filter='pytest<5'
tox -e $TOXENV $TOXARGS --pypi-filter='pytest<5.4' -- $TOXPOSARGS
echo ''
echo '########################################################################'
