#!/bin/bash

if [[ $DEBUG == True ]]; then
    set -x
fi

echo "==================== Starting executing ci-helpers scripts ====================="

# Install conda
# http://conda.pydata.org/docs/travis.html#the-travis-yml-file

miniconda_version=3
[[ "$PYTHON_VERSION" == "2.7" ]] &&  miniconda_version=2

wget https://repo.continuum.io/miniconda/Miniconda${miniconda_version}-latest-Linux-x86_64.sh -O miniconda.sh;
bash miniconda.sh -b -p $HOME/miniconda
export PATH="$HOME/miniconda/bin:$PATH"

# Install common Python dependencies
source "$( dirname "${BASH_SOURCE[0]}" )"/setup_dependencies_common.sh

if [[ $SETUP_XVFB == True ]]; then
    export DISPLAY=:99.0
    sh -e /etc/init.d/xvfb start
fi

echo "================= Returning executing local .travis.yml script ================="
