#!/bin/bash

# Workaround for https://github.com/travis-ci/travis-ci/issues/6307, which
# caused the following error on MacOS X workers:
#
# Warning, RVM 1.26.0 introduces signed releases and automated check of signatures when GPG software found.
# /Users/travis/build.sh: line 109: shell_session_update: command not found
#
command curl -sSL https://rvm.io/mpapis.asc | gpg --import -;
rvm get stable

# Install conda (http://conda.pydata.org/docs/travis.html#the-travis-yml-file)
# Note that we pin the Miniconda version to avoid issues when new versions are released.
# This can be updated from time to time.
if [[ -z "${MINICONDA_VERSION}" ]]; then
    MINICONDA_VERSION=4.7.10
fi

# Set default OSX deployment target version to 10.9, since this is required for
# compiling C++ code with llvm/clang when -stdlib=libc++ is specified.
# Note that, for linking, version 10.7 should suffice.
if [[ -z "${MACOSX_DEPLOYMENT_TARGET}" ]]; then
    export MACOSX_DEPLOYMENT_TARGET=10.9
elif [[ "${MACOSX_DEPLOYMENT_TARGET}" == "clang_default" ]]; then
    export MACOSX_DEPLOYMENT_TARGET=""
fi

wget https://repo.continuum.io/miniconda/Miniconda3-${MINICONDA_VERSION}-MacOSX-x86_64.sh -O miniconda.sh
bash miniconda.sh -b -p $HOME/miniconda
$HOME/miniconda/bin/conda init bash
source ~/.bash_profile
conda activate base

# Install common Python dependencies
source "$( dirname "${BASH_SOURCE[0]}" )"/setup_dependencies_common.sh
