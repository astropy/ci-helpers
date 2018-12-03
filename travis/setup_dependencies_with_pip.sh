#!/bin/bash -x

# This is an alternative route, which is triggered by the presence of the
# USE_PIP_INSTALL environment variable, which should be set to True. In this
# case, dependencies are installed based on the content of install_requires and
# extras_requires in setup.py. This route is deliberately minimal, so we should
# add as few extra features to it as possible.

# The recognized variables here are:
#
# $PYTHON_VERSION: used to determine the Python version to set up
# $CONDA_DEPENDENCIES: added to the conda create command
# $EXTRAS_INSTALL: included inside [] in the pip install command
# $PIP_DEPENDENCIES: added to the pip install command

set -e

if [[ -z $PYTHON_VERSION ]]; then
    export PYTHON_VERSION=$TRAVIS_PYTHON_VERSION
fi

if [[ ! -z $PYTHON_VERSION ]]; then
    PYTHON_OPTION="python=$PYTHON_VERSION"
else
    PYTHON_OPTION=""
fi

conda create $QUIET -n test $PYTHON_OPTION $CONDA_DEPENDENCIES

source activate test

if [ -z $EXTRAS_INSTALL ]; then
    pip install -e . $PIP_DEPENDENCIES;
else
    pip install -e .[$EXTRAS_INSTALL] $PIP_DEPENDENCIES;
fi
