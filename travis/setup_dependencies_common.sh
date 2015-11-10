#!/bin/bash -x

hash -r
conda config --set always_yes yes --set changeps1 no
conda update -q conda
conda info -a

if [[ -z $PYTHON_VERSION ]]; then
    PYTHON_VERSION=$TRAVIS_PYTHON_VERSION
fi

# CONDA
conda create -n test -c astropy-ci-extras python=$PYTHON_VERSION pip
source activate test

# EGG_INFO
if [[ $SETUP_CMD == egg_info ]]; then
    return  # no more dependencies needed
fi

# PEP8
if [[ $MAIN_CMD == pep8* ]]; then
    $PIP_INSTALL pep8
    return  # no more dependencies needed
fi

# CORE DEPENDENCIES
conda install pytest Cython jinja2 pip

# NUMPY
if [[ $NUMPY_VERSION == dev ]] || [[ $NUMPY_VERSION == development ]]; then
    $PIP_INSTALL git+http://github.com/numpy/numpy.git
    export CONDA_INSTALL="conda install -c astropy-ci-extras python=$PYTHON_VERSION"
else
    conda install  numpy=$NUMPY_VERSION
    export CONDA_INSTALL="conda install -c astropy-ci-extras python=$PYTHON_VERSION numpy=$NUMPY_VERSION"
fi

# ASTROPY
if [[ ! -z $ASTROPY_VERSION ]]; then
    if [[ $ASTROPY_VERSION == development ]] || [[ $ASTROPY_VERSION == dev ]]; then
        $PIP_INSTALL git+http://github.com/astropy/astropy.git#egg=astropy;
    elif [[ $ASTROPY_VERSION == stable ]]; then
        $CONDA_INSTALL astropy;
    else
        $CONDA_INSTALL astropy=$ASTROPY_VERSION;
    fi
fi

# Now set up shortcut to conda install command to make sure the Python and Numpy
# versions are always explicitly specified.

# OPTIONAL DEPENDENCIES
if $INSTALL_OPTIONAL; then
    $CONDA_INSTALL $OPTIONAL_DEPENDENCIES
fi

# DOCUMENTATION DEPENDENCIES
# build_sphinx needs sphinx and matplotlib (for plot_directive).
if [[ $SETUP_CMD == build_sphinx* ]]; then
    $CONDA_INSTALL Sphinx matplotlib
fi

# COVERAGE DEPENDENCIES
if [[ $SETUP_CMD == 'test --coverage' ]]; then
  # TODO can use latest version of coverage (4.0) once astropy 1.1 is out
  # with the fix of https://github.com/astropy/astropy/issues/4175.
  pip install coverage==3.7.1;
  pip install coveralls;
fi
