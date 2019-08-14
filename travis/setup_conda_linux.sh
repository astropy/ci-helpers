#!/bin/bash

# Install conda (http://conda.pydata.org/docs/travis.html#the-travis-yml-file)
# Note that we pin the Miniconda version to avoid issues when new versions are released.
# This can be updated from time to time.
if [[ -z "${MINICONDA_VERSION}" ]]; then
    MINICONDA_VERSION=4.7.10
fi
wget https://repo.continuum.io/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh -O miniconda.sh --progress=dot:mega
# Create .conda directory before install to workaround conda bug
# See https://github.com/ContinuumIO/anaconda-issues/issues/11148
mkdir $HOME/.conda
bash miniconda.sh -b -p $HOME/miniconda
$HOME/miniconda/bin/conda init bash
source ~/.bash_profile
conda activate base

# Install common Python dependencies
source "$( dirname "${BASH_SOURCE[0]}" )"/setup_dependencies_common.sh

if [[ $SETUP_XVFB == True ]]; then
    export DISPLAY=:99.0
    /sbin/start-stop-daemon --start --quiet --pidfile /tmp/custom_xvfb_99.pid --make-pidfile --background --exec /usr/bin/Xvfb -- :99 -screen 0 1920x1200x24 -ac +extension GLX +render -noreset
fi
