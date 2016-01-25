#!/bin/bash -x

hash -r

set -e

conda config --set always_yes yes --set changeps1 no

shopt -s nocasematch

if [[ $DEBUG == True ]]; then
    QUIET=''
else
    QUIET='-q'
fi

if [[ -z $ASTROPY_LTS_VERSION ]]; then
   ASTROPY_LTS_VERSION=1.0
fi

if [[ -z $CONDA_CHANNELS ]]; then
    CONDA_CHANNELS='astropy-ci-extras astropy'
fi

if [[ -z $CONDA_DEPENDENCIES_FLAGS ]]; then
   CONDA_DEPENDENCIES_FLAGS=''
fi

if [[ -z $PIP_DEPENDENCIES_FLAGS ]]; then
   PIP_DEPENDENCIES_FLAGS=''
fi

for channel in $CONDA_CHANNELS
do
    conda config --add channels $channel
done

conda update $QUIET conda

# Use utf8 encoding. Should be default, but this is insurance against
# future changes
export PYTHONIOENCODING=UTF8

if [[ -z $PYTHON_VERSION ]]; then
    PYTHON_VERSION=$TRAVIS_PYTHON_VERSION
fi

# CONDA
conda create $QUIET -n test python=$PYTHON_VERSION
source activate test

# EGG_INFO
if [[ $SETUP_CMD == egg_info ]]; then
    return  # no more dependencies needed
fi

# CORE DEPENDENCIES
conda install $QUIET pytest pip

export PIP_INSTALL='pip install'

# PEP8
if [[ $MAIN_CMD == pep8* ]]; then
    $PIP_INSTALL pep8
    return  # no more dependencies needed
fi

# Pin required versions for dependencies, howto is in FAQ of conda
# http://conda.pydata.org/docs/faq.html#pinning-packages
if [[ ! -z $CONDA_DEPENDENCIES ]]; then
    pin_file=$HOME/miniconda/envs/test/conda-meta/pinned
    echo $CONDA_DEPENDENCIES | awk '{print tolower($0)}' | tr " " "\n" | \
        sed -E -e 's|([a-z0-9]+)([=><!])|\1 \2|g' -e 's| =([0-9])| ==\1|g' > $pin_file

    if [[ $DEBUG == True ]]; then
        cat $pin_file
    fi

    # Let env variable version number override this pinned version
    for package in $(awk '{print $1}' $pin_file); do
        version=$(eval echo -e \$$(echo $package | tr "-" "_" | \
            awk '{print toupper($0)"_VERSION"}'))
        if [[ ! -z $version ]]; then
            awk -v package=$package -v version=$version \
                '{if ($1 == package) print package" " version"*";
                  else print $0}' \
                $pin_file > /tmp/pin_file_temp
            mv /tmp/pin_file_temp $pin_file
       fi
    done

    # Do in the pin file what conda silently does on the command line, to
    # extend the underspecified version numbers with *
    awk -F == '{if (NF==1) print $0; else print $1, $2"*"}' \
        $pin_file > /tmp/pin_file_temp
    mv /tmp/pin_file_temp $pin_file

    # We should remove the version numbers from CONDA_DEPENDENCIES to avoid
    # the conflict with the *_VERSION env variables
    CONDA_DEPENDENCIES=$(awk '{printf tolower($1)" "}' $pin_file)
    # Cutting off the trailing space
    CONDA_DEPENDENCIES=${CONDA_DEPENDENCIES%?}

    if [[ $DEBUG == True ]]; then
        cat $pin_file
        echo $CONDA_DEPENDENCIES
    fi
fi

# NUMPY
if [[ $NUMPY_VERSION == dev* ]]; then
    # Install at the bottom of this script
    export CONDA_INSTALL="conda install $QUIET python=$PYTHON_VERSION"
elif [[ $NUMPY_VERSION == stable ]]; then
    conda install $QUIET numpy
    export CONDA_INSTALL="conda install $QUIET python=$PYTHON_VERSION"
elif [[ ! -z $NUMPY_VERSION ]]; then
    conda install $QUIET numpy=$NUMPY_VERSION
    export CONDA_INSTALL="conda install $QUIET python=$PYTHON_VERSION numpy=$NUMPY_VERSION"
else
    export CONDA_INSTALL="conda install $QUIET python=$PYTHON_VERSION"
fi

# ASTROPY
if [[ ! -z $ASTROPY_VERSION ]]; then
    if [[ $ASTROPY_VERSION == dev* ]]; then
        : # Install at the bottom of this script
    elif [[ $ASTROPY_VERSION == stable ]]; then
        $CONDA_INSTALL astropy
    elif [[ $ASTROPY_VERSION == lts ]]; then
        $CONDA_INSTALL astropy=$ASTROPY_LTS_VERSION
    else
        $CONDA_INSTALL astropy=$ASTROPY_VERSION
    fi
fi

# ADDITIONAL DEPENDENCIES (can include optionals, too)
if [[ ! -z $CONDA_DEPENDENCIES ]]; then
    $CONDA_INSTALL $CONDA_DEPENDENCIES $CONDA_DEPENDENCIES_FLAGS
fi

if [[ ! -z $PIP_DEPENDENCIES ]]; then
    $PIP_INSTALL $PIP_DEPENDENCIES $PIP_DEPENDENCIES_FLAGS
fi

# PARALLEL BUILDS
if [[ $SETUP_CMD == *parallel* ]]; then
    $PIP_INSTALL pytest-xdist
fi

# OPEN FILES
if [[ $SETUP_CMD == *open-files* ]]; then
    $CONDA_INSTALL psutil
fi

# DOCUMENTATION DEPENDENCIES
# build_sphinx needs sphinx and matplotlib (for plot_directive).
if [[ $SETUP_CMD == build_sphinx* ]] || [[ $SETUP_CMD == build_docs* ]]; then
    # TODO: remove pinned matplotlib version once
    # https://github.com/matplotlib/matplotlib/issues/5836 is fixed
    $CONDA_INSTALL Sphinx "matplotlib<=1.5.1"
fi

# COVERAGE DEPENDENCIES
if [[ $SETUP_CMD == *coverage* ]]; then
    # TODO can use latest version of coverage (4.0) once astropy 1.1 is out
    # with the fix of https://github.com/astropy/astropy/issues/4175.
    $CONDA_INSTALL coverage==3.7.1
    $PIP_INSTALL coveralls
fi

# NUMPY DEV

# We now install Numpy dev - this has to be done last, otherwise conda might
# install a stable version of Numpy as a dependency to another package, which
# would override Numpy dev.

if [[ $NUMPY_VERSION == dev* ]]; then
    conda install $QUIET Cython
    $PIP_INSTALL git+http://github.com/numpy/numpy.git#egg=numpy --upgrade
fi

# ASTROPY DEV

# We now install Astropy dev - this has to be done last, otherwise conda might
# install a stable version of Astropy as a dependency to another package, which
# would override Astropy dev. Also, if we are installing Numpy dev, we need to
# compile Astropy dev against Numpy dev.

if [[ $ASTROPY_VERSION == dev* ]]; then
    $CONDA_INSTALL Cython jinja2
    $PIP_INSTALL git+http://github.com/astropy/astropy.git#egg=astropy --upgrade
fi

if [[ $DEBUG == True ]]; then
    # include debug information about the current conda install
    conda install -n root _license
    conda info -a
fi

set +x
