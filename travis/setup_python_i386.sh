#!/bin/bash

if [[ $DEBUG == True ]]; then
    set -x
fi

echo "==================== Starting executing ci-helpers scripts ====================="

if [[ ! -z $CONDA_DEPENDENCIES ]]; then
    echo "Can't install conda packages in this mode";
    exit 100;
fi

# Remember start directory

start=`pwd`

# Go to temporary directory

cd `mktemp -d -t test`

export PATH=$HOME/python_32bit/bin:$PATH

# Install Python

case $PYTHON_VERSION in
2.6)
  FULL_PYTHON_VERSION=2.6.9
  ;;
2.7)
  FULL_PYTHON_VERSION=2.7.10
  ;;
3.2)
  FULL_PYTHON_VERSION=3.2.6
  ;;
3.3)
  FULL_PYTHON_VERSION=3.3.6
  ;;
3.4)
  FULL_PYTHON_VERSION=3.4.4
  ;;
3.5)
  FULL_PYTHON_VERSION=3.5.1
  ;;
esac

wget "https://www.python.org/ftp/python/"$FULL_PYTHON_VERSION"/Python-"$FULL_PYTHON_VERSION".tgz"

tar xvzf "Python-"$FULL_PYTHON_VERSION".tgz" >& tar.log
if [[ $DEBUG == True ]]; then cat tar.log; fi

cd "Python-"$FULL_PYTHON_VERSION

./configure MACOSX_DEPLOYMENT_TARGET=10.6 CFLAGS="-m32" LDFLAGS="-m32" --prefix=$HOME/python_32bit >& configure.log;

if [[ $DEBUG == True ]]; then cat configure.log; fi

make >& make.log
if [[ $DEBUG == True ]]; then cat make.log; fi

make install >& make_install.log
if [[ $DEBUG == True ]]; then cat make_install.log; fi

cd ..

# Check path to Python

which python

if [[ `which python` != $HOME/python_32bit/bin/python ]]; then
  echo "An error occurred when compiling Python"
  exit 100
fi

# Install setuptools

wget https://pypi.python.org/packages/source/s/setuptools/setuptools-19.1.tar.gz
tar xvzf setuptools-19.1.tar.gz
cd setuptools-19.1
python setup.py install
cd ..

# Install pip

easy_install pip

# Install pytest

pip install pytest mock

# Install pip dependencies

F90="gfortran -m32" F77="gfortran -m32" FC="gfortran -m32" CC="gcc -m32" pip install $PIP_DEPENDENCIES $PIP_DEPENDENCIES_FLAGS --no-use-wheel

# Go back to start directory

cd $start

echo "================= Returning executing local .travis.yml script ================="
