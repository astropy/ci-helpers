#!/bin/bash -x

hash -r

set -e

conda config --set always_yes yes --set changeps1 no
conda config --add channels defaults

shopt -s nocasematch

export LATEST_ASTROPY_STABLE=1.2
LATEST_NUMPY_STABLE=1.11

if [[ $DEBUG == True ]]; then
    QUIET=''
else
    QUIET='-q'
fi

if [[ -z $ASTROPY_LTS_VERSION ]]; then
   ASTROPY_LTS_VERSION=1.0
fi

if [[ -z $CONDA_CHANNELS ]]; then
    CONDA_CHANNELS='astropy openastronomy astropy-ci-extras'
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

# We need to add this after the update, otherwise the ``channel_priority``
# key may not yet exists
conda config  --set channel_priority false

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
# PEP8 has been renamed to pycodestyle, keep both here for now
if [[ $MAIN_CMD == pep8* ]]; then
    $PIP_INSTALL pep8
    return  # no more dependencies needed
fi

if [[ $MAIN_CMD == pycodestyle* ]]; then
    $PIP_INSTALL pycodestyle
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
    # We install nomkl here to make sure that Numpy and Scipy versions
    # installed subsequently don't depend on the MKL. If we don't do this, then
    # we run into issues when we install the developer version of Numpy
    # because it is then not compiled against the MKL, and one runs into issues
    # if Scipy *is* still compiled against the MKL.
    conda install $QUIET nomkl
    # We then install Numpy itself at the bottom of this script
    export CONDA_INSTALL="conda install $QUIET python=$PYTHON_VERSION"
elif [[ $NUMPY_VERSION == stable ]]; then
    conda install $QUIET numpy=$LATEST_NUMPY_STABLE
    export CONDA_INSTALL="conda install $QUIET python=$PYTHON_VERSION numpy=$LATEST_NUMPY_STABLE"
elif [[ $NUMPY_VERSION == pre* ]]; then
    conda install $QUIET numpy
    export CONDA_INSTALL="conda install $QUIET python=$PYTHON_VERSION"
    if [[ -z $(pip list -o --pre | grep numpy | \
            grep -E "[0-9]rc[0-9]|[0-9][ab][0-9]") ]]; then
        # We want to stop the script if there isn't a pre-release available,
        # as in that case it would be just another build using the stable
        # version.
        exit
    fi
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
    elif [[ $ASTROPY_VERSION == pre* ]]; then
        conda install astropy
        if [[ -z $(pip list -o --pre | grep astropy | \
            grep -E "[0-9]rc[0-9]|[0-9][ab][0-9]") ]]; then
            # We want to stop the script if there isn't a pre-release available,
            # as in that case it would be just another build using the stable
            # version.
            exit
        fi
    elif [[ $ASTROPY_VERSION == stable ]]; then
        $CONDA_INSTALL astropy
    elif [[ $ASTROPY_VERSION == lts ]]; then
        $CONDA_INSTALL astropy=$ASTROPY_LTS_VERSION
    else
        $CONDA_INSTALL astropy=$ASTROPY_VERSION
    fi
fi

# DOCUMENTATION DEPENDENCIES
# build_sphinx needs sphinx and matplotlib (for plot_directive).
if [[ $SETUP_CMD == build_sphinx* ]] || [[ $SETUP_CMD == build_docs* ]]; then
    # Check whether there are any version setting env variables, pin them if
    # there are (only need to deal with the case when they aren't listed in
    # CONDA_DEPENDENCIES, otherwise this was already dealt with)

    pin_file=$HOME/miniconda/envs/test/conda-meta/pinned
    if [[ ! -z $MATPLOTLIB_VERSION ]]; then
        if [[ -z $(grep matplotlib $pin_file) ]]; then
            echo "matplotlib ${MATPLOTLIB_VERSION}*" >> $pin_file
        fi
    fi

    # This is a temporary workaround of 2 warnings that appeared in the new
    # 1.4 sphinx version, and that should be dealt with in
    # astropy-helpers. This was we allow to override this version
    # restriction by setting this variable in .travis.yml
    if [[ -z $SPHINX_VERSION ]]; then
        SPHINX_VERSION='<1.4'
    fi

    if [[ ! -z $SPHINX_VERSION ]]; then
        if [[ -z $(grep sphinx $pin_file) ]]; then
            echo "sphinx ${SPHINX_VERSION}*" >> $pin_file
        fi
    fi

    if [[ $DEBUG == True ]]; then
        cat $pin_file
    fi

    $CONDA_INSTALL sphinx matplotlib
fi

# ADDITIONAL DEPENDENCIES (can include optionals, too)
if [[ ! -z $CONDA_DEPENDENCIES ]]; then
    $CONDA_INSTALL $CONDA_DEPENDENCIES $CONDA_DEPENDENCIES_FLAGS
fi

# PARALLEL BUILDS
if [[ $SETUP_CMD == *parallel* ]]; then
    $PIP_INSTALL pytest-xdist
fi

# OPEN FILES
if [[ $SETUP_CMD == *open-files* ]]; then
    $CONDA_INSTALL psutil
fi

# NUMPY DEV and PRE

# We now install Numpy dev - this has to be done last, otherwise conda might
# install a stable version of Numpy as a dependency to another package, which
# would override Numpy dev or pre.

if [[ $NUMPY_VERSION == dev* ]]; then
    conda install $QUIET Cython
    $PIP_INSTALL git+https://github.com/numpy/numpy.git#egg=numpy --upgrade --no-deps
fi

if [[ $NUMPY_VERSION == pre* ]]; then
    $PIP_INSTALL --pre --upgrade numpy
fi

# ASTROPY DEV and PRE

# We now install Astropy dev - this has to be done last, otherwise conda might
# install a stable version of Astropy as a dependency to another package, which
# would override Astropy dev. Also, if we are installing Numpy dev, we need to
# compile Astropy dev against Numpy dev. We need to include --no-deps to make
# sure that Numpy doesn't get upgraded.

if [[ $ASTROPY_VERSION == dev* ]]; then
    $CONDA_INSTALL Cython jinja2
    $PIP_INSTALL git+https://github.com/astropy/astropy.git#egg=astropy --upgrade --no-deps
fi

if [[ $ASTROPY_VERSION == pre* ]]; then
    $PIP_INSTALL --pre --upgrade --no-deps astropy
fi

# ASTROPY STABLE

# Due to recent instability in conda, and as new releases are not built in
# astropy-ci-extras, this workaround ensures that we use the latest stable
# version of astropy.

if [[ $ASTROPY_VERSION == stable ]]; then
    if $(python -c "from distutils.version import LooseVersion; import astropy;\
                    import os; print(LooseVersion(astropy.__version__) <\
                    LooseVersion(os.environ['LATEST_ASTROPY_STABLE']))"); then
        $PIP_INSTALL --upgrade --no-deps astropy==$LATEST_ASTROPY_STABLE
    fi
fi

# PIP DEPENDENCIES

# We finally install the dependencies listed in PIP_DEPENDENCIES. We do this
# after installing the Numpy versions of Numpy or Astropy. If we didn't do this,
# then calling pip earlier could result in the stable version of astropy getting
# installed, and then overritten later by the dev version (which would waste
# build time)

if [[ ! -z $PIP_DEPENDENCIES ]]; then
    $PIP_INSTALL $PIP_DEPENDENCIES $PIP_DEPENDENCIES_FLAGS
fi


# COVERAGE DEPENDENCIES

# Both cpp-coveralls and coveralls install a 'coveralls' command, but we want
# the one from the coveralls package to always take precedence, so we have to
# install this now in case the user installs cpp-coveralls via PIP_DEPENDENCIES.

if [[ $SETUP_CMD == *coverage* ]]; then
    # TODO can use latest version of coverage (4.0) once astropy 1.1 is out
    # with the fix of https://github.com/astropy/astropy/issues/4175.
    # We install requests with conda since it's required by coveralls.
    $CONDA_INSTALL coverage==3.7.1 requests
    $PIP_INSTALL coveralls
fi


# SPHINX BUILD MPL FONT CACHING WORKAROUND

# This is required to avoid Sphinx build failures due to a warning that
# comes from the mpl FontManager(). The workaround is to initialize the
# cache before starting the tests/docs build. See details in
# https://github.com/matplotlib/matplotlib/issues/5836

if [[ $SETUP_CMD == build_sphinx* ]] || [[ $SETUP_CMD == build_docs* ]]; then
    python -c "import matplotlib.pyplot"
fi

# DEBUG INFO

if [[ $DEBUG == True ]]; then
    # include debug information about the current conda install
    conda install -n root _license
    conda info -a
fi

set +x
