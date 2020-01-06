#!/bin/bash

# Install conda (http://conda.pydata.org/docs/travis.html#the-travis-yml-file)
# Note that we pin the Miniconda version to avoid issues when new versions are released.
# This can be updated from time to time.
if [[ -z "${MINICONDA_VERSION}" ]]; then
    MINICONDA_VERSION=4.7.10
fi

if [ `uname -m` = 'aarch64' ]; then
   sudo apt-get install python3 python3-dev python3-setuptools cython cython3 python3-pip gcc gfortran libblas-dev liblapack-dev;
   wget -q "https://github.com/Archiconda/build-tools/releases/download/0.2.3/Archiconda3-0.2.3-Linux-aarch64.sh" -O archiconda.sh
   chmod +x archiconda.sh
   bash archiconda.sh -b -p $HOME/miniconda
   export PATH="$HOME/miniconda/bin:$PATH"
   sudo cp -r $HOME/miniconda/bin/* /usr/bin/
   hash -r
   sudo conda config --set always_yes yes --set changeps1 no
   sudo conda update -q conda
   sudo conda info -a
   source activate base
   source "$( dirname "${BASH_SOURCE[0]}" )"/setup_dependencies_common.sh
else
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
   source "$( dirname "${BASH_SOURCE[0]}" )"/setup_dependencies_common.sh
   if [[ $SETUP_XVFB == True ]]; then
    export DISPLAY=:99.0
    /sbin/start-stop-daemon --start --quiet --pidfile /tmp/custom_xvfb_99.pid --make-pidfile --background --exec /usr/bin/Xvfb -- :99 -screen 0 1920x1200x24 -ac +extension GLX +render -noreset
   fi
fi
export PATH=$MINICONDA_DIR/bin:$PATH
