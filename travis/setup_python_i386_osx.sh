#!/bin/bash

if [[ $DEBUG == True ]]; then
    set -x
fi

echo "==================== Starting executing ci-helpers scripts ====================="

if [[ ! -z $CONDA_DEPENDENCIES ]]; then
    echo "Can't install conda packages in this mode";
    exit 100;
fi


# Install Python

wget https://www.python.org/ftp/python/2.7.11/Python-2.7.11.tgz
tar xvzf Python-2.7.11.tgz
cd Python-2.7.11

./configure MACOSX_DEPLOYMENT_TARGET=10.6 CFLAGS="-arch i386" LDFLAGS="-arch i386" --prefix=$HOME/python_32bit >& configure.log
if [[ $DEBUG == True ]]; then cat configure.log; fi
  
make >& make.log
if [[ $DEBUG == True ]]; then cat make.log; fi

make install >& make_install.log
if [[ $DEBUG == True ]]; then cat make_install.log; fi

export PATH=$HOME/python_32bit/bin:$PATH

# Install setuptools

wget https://pypi.python.org/packages/source/s/setuptools/setuptools-19.1.tar.gz
tar xvzf setuptools-19.1.tar.gz
cd setuptools-19.1
python setup.py install

# Install pip

easy_install pip

# Install pytest

pip install pytest

# Install pip dependencies

F90="gfortran -m32" F77="gfortran -m32" FC="gfortran -m32" CC="gcc -m32" pip install $PIP_DEPENDENCIES $PIP_DEPENDENCIES_FLAGS --no-use-wheel

echo "================= Returning executing local .travis.yml script ================="
