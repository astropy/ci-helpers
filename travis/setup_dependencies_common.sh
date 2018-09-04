#!/bin/bash -x

hash -r

set -e

# We need to do this before updating conda, as $CONDA_CHANNELS may be a
# conda environment variable for some Miniconda versions, too that needs to
# be space separated.
if [[ ! -z $CONDA_CHANNELS ]]; then
    for channel in $CONDA_CHANNELS; do
        conda config --add channels $channel
    done
    unset CONDA_CHANNELS
fi

conda config --set always_yes yes --set changeps1 no

shopt -s nocasematch

if [[ -z $PYTHON_VERSION ]]; then
    export PYTHON_VERSION=$TRAVIS_PYTHON_VERSION
fi

# We will use the 2.0.x releases as "stable" for Python 2.7 and 3.4
if [[ $(python -c "from distutils.version import LooseVersion; import os;\
        print(LooseVersion(os.environ['PYTHON_VERSION']) < '3.5')") == False ]]; then
    export LATEST_ASTROPY_STABLE=3.0.3
else
    export LATEST_ASTROPY_STABLE=2.0.7
    export NO_PYTEST_ASTROPY=True
fi
ASTROPY_LTS_VERSION=2.0.7
LATEST_NUMPY_STABLE=1.14
LATEST_SUNPY_STABLE=0.9.2

if [[ -z $PIP_FALLBACK ]]; then
    PIP_FALLBACK=true
fi

if [[ $DEBUG == True ]]; then
    QUIET=''
else
    QUIET='-q'
fi

if [[ -z $CONDA_DEPENDENCIES_FLAGS ]]; then
   CONDA_DEPENDENCIES_FLAGS=''
fi

if [[ -z $PIP_DEPENDENCIES_FLAGS ]]; then
   PIP_DEPENDENCIES_FLAGS=''
fi

# We pin the version for conda as it's not the most stable package from
# release to release. Add note here if version is pinned due to a bug upstream.
if [[ -z $CONDA_VERSION ]]; then
    CONDA_VERSION=4.5.11
fi

PIN_FILE_CONDA=$HOME/miniconda/conda-meta/pinned

echo "conda ${CONDA_VERSION}" > $PIN_FILE_CONDA

conda install $QUIET conda

if [[ -z $CONDA_CHANNEL_PRIORITY ]]; then
    CONDA_CHANNEL_PRIORITY=false
else
    # Make lowercase
    CONDA_CHANNEL_PRIORITY=$(echo $CONDA_CHANNEL_PRIORITY | awk '{print tolower($0)}')
fi

# We need to add this after the update, otherwise the ``channel_priority``
# key may not yet exists
conda config  --set channel_priority $CONDA_CHANNEL_PRIORITY

# Use utf8 encoding. Should be default, but this is insurance against
# future changes
export PYTHONIOENCODING=UTF8

# CONDA
if [[ -z $CONDA_ENVIRONMENT ]]; then
    conda create $QUIET -n test python=$PYTHON_VERSION
else
    conda env create $QUIET -n test -f $CONDA_ENVIRONMENT
fi
source activate test

# PIN FILE
PIN_FILE=$HOME/miniconda/envs/test/conda-meta/pinned
# ensure the PIN_FILE exists
touch $PIN_FILE

if [[ $DEBUG == True ]]; then
    conda config --show
fi

# EGG_INFO
if [[ $SETUP_CMD == egg_info ]]; then
    return  # no more dependencies needed
fi

# CORE DEPENDENCIES

if [[ ! -z $PYTEST_VERSION ]]; then
    echo "pytest ${PYTEST_VERSION}*" >> $PIN_FILE
else
    # pin pytest to avoid upstream issues
    # https://github.com/astropy/pytest-doctestplus/issues/22
    echo "pytest <3.7" >> $PIN_FILE
fi

if [[ ! -z $PIP_VERSION ]]; then
    echo "pip ${PIP_VERSION}*" >> $PIN_FILE
fi

# We use the channel astropy-ci-extras to host pytest 2.7.3 that is
# compatible with LTS 1.0.x astropy. We need to disable channel priority for
# this step to make sure the latest version is picked up when
# CHANNEL_PRIORITY is set to True above.
conda install -c astropy-ci-extras --no-channel-priority $QUIET pytest pip || ( \
    $PIP_FALLBACK && ( \
    if [[ ! -z $PYTEST_VERSION ]]; then
        echo "Installing pytest with conda was unsuccessful, using pip instead"
        conda install $QUIET pip
        pip install pytest==$PYTEST_VERSION
        awk '{if ($1 != "pytest") print $0}' $PIN_FILE > /tmp/pin_file_temp
        mv /tmp/pin_file_temp $PIN_FILE
    fi)
)

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

if [[ $MAIN_CMD == flake8* ]]; then
    $PIP_INSTALL flake8
    return  # no more dependencies needed
fi

if [[ $MAIN_CMD == pylint* ]]; then
    $PIP_INSTALL pylint

    # Installing backports when using python 2.7. Add required backports to
    # the list
    if [[ $PYTHON_VERSION == 2.7 ]]; then
        $PIP_INSTALL backports.functools_lru_cache
    fi

    return  # no more dependencies needed
fi

# Pin required versions for dependencies, howto is in FAQ of conda
# http://conda.pydata.org/docs/faq.html#pinning-packages
if [[ ! -z $CONDA_DEPENDENCIES ]]; then

    # On the defaults conda channel mpl currently segfault with newer sip
    # versions. While it doesn't happen for all python version, there are
    # many packages running into the issue, so we better have a temporarily
    # limitation for everything here.
    if [[ ! -z $(echo $CONDA_DEPENDENCIES | grep matplotlib) ]]; then
        CONDA_DEPENDENCIES=${CONDA_DEPENDENCIES}" sip<4.19"
    fi

    echo $CONDA_DEPENDENCIES | awk '{print tolower($0)}' | tr " " "\n" | \
        sed -E -e 's|([a-z0-9]+)([=><!])|\1 \2|g' -e 's| =([0-9])| ==\1|g' >> $PIN_FILE

    if [[ $DEBUG == True ]]; then
        cat $PIN_FILE
    fi

    # Let env variable version number override this pinned version
    for package in $(awk '{print $1}' $PIN_FILE); do
        version=$(eval echo -e \$$(echo $package | tr "-" "_" | \
            awk '{print toupper($0)"_VERSION"}'))
        if [[ ! -z $version ]]; then
            awk -v package=$package -v version=$version \
                '{if ($1 == package) print package" " version"*";
                  else print $0}' \
                $PIN_FILE > /tmp/pin_file_temp
            mv /tmp/pin_file_temp $PIN_FILE
       fi
    done

    # Do in the pin file what conda silently does on the command line, to
    # extend the underspecified version numbers with *
    awk -F == '{if (NF==1) print $0; else print $1, $2"*"}' \
        $PIN_FILE > /tmp/pin_file_temp
    mv /tmp/pin_file_temp $PIN_FILE

    # We should remove the version numbers from CONDA_DEPENDENCIES to avoid
    # the conflict with the *_VERSION env variables
    CONDA_DEPENDENCIES=$(awk '{printf tolower($1)" "}' $PIN_FILE)
    # Cutting off the trailing space
    CONDA_DEPENDENCIES=${CONDA_DEPENDENCIES%?}

    if [[ $DEBUG == True ]]; then
        cat $PIN_FILE
        echo $CONDA_DEPENDENCIES
    fi
fi

# NUMPY
# We use --no-pin to avoid installing other dependencies just yet.

if [[ $NUMPY_VERSION == dev* ]]; then
    # We install nomkl here to make sure that Numpy and Scipy versions
    # installed subsequently don't depend on the MKL. If we don't do this, then
    # we run into issues when we install the developer version of Numpy
    # because it is then not compiled against the MKL, and one runs into issues
    # if Scipy *is* still compiled against the MKL.
    conda install $QUIET --no-pin nomkl
    # We then install Numpy itself at the bottom of this script
    export CONDA_INSTALL="conda install $QUIET python=$PYTHON_VERSION"
elif [[ $NUMPY_VERSION == stable ]]; then
    conda install $QUIET --no-pin numpy=$LATEST_NUMPY_STABLE
    export NUMPY_OPTION="numpy=$LATEST_NUMPY_STABLE"
    export CONDA_INSTALL="conda install $QUIET python=$PYTHON_VERSION numpy=$LATEST_NUMPY_STABLE"
elif [[ $NUMPY_VERSION == pre* ]]; then
    conda install $QUIET --no-pin nomkl numpy
    export NUMPY_OPTION=""
    export CONDA_INSTALL="conda install $QUIET python=$PYTHON_VERSION"
    if [[ -z $(pip list -o --pre | grep numpy | \
            grep -E "[0-9]rc[0-9]|[0-9][ab][0-9]") ]]; then
        # We want to stop the script if there isn't a pre-release available,
        # as in that case it would be just another build using the stable
        # version.
        echo "Prerelease for numpy is not available, stopping test"
        travis_terminate 0
    fi
elif [[ ! -z $NUMPY_VERSION ]]; then
    conda install $QUIET --no-pin numpy=$NUMPY_VERSION
    export NUMPY_OPTION="numpy=$NUMPY_VERSION"
    export CONDA_INSTALL="conda install $QUIET python=$PYTHON_VERSION numpy=$NUMPY_VERSION"
else
    export NUMPY_OPTION=""
    export CONDA_INSTALL="conda install $QUIET python=$PYTHON_VERSION"
fi

# ASTROPY
if [[ ! -z $ASTROPY_VERSION ]]; then
    if [[ $ASTROPY_VERSION == dev* ]]; then
        : # Install at the bottom of this script
    elif [[ $ASTROPY_VERSION == pre* ]]; then
        # We use --no-pin to avoid installing other dependencies just yet
        conda install --no-pin astropy
        if [[ -z $(pip list -o --pre | grep astropy | \
            grep -E "[0-9]rc[0-9]|[0-9][ab][0-9]") ]]; then
            # We want to stop the script if there isn't a pre-release available,
            # as in that case it would be just another build using the stable
            # version.
            echo "Prerelease for astropy is not available, stopping test"
            travis_terminate 0
        fi
    elif [[ $ASTROPY_VERSION == stable ]]; then
        # We add astropy to the pin file to make sure it won't get downgraded
        echo "astropy ${LATEST_ASTROPY_STABLE}*" >> $PIN_FILE

        if [[ $NO_PYTEST_ASTROPY == True ]]; then
            ASTROPY_OPTION="$LATEST_ASTROPY_STABLE"
        else
            ASTROPY_OPTION="$LATEST_ASTROPY_STABLE pytest-astropy"
        fi

    elif [[ $ASTROPY_VERSION == lts ]]; then
        # We ship the build if the LTS version is the same as latest stable
        if [[ $LATEST_ASTROPY_STABLE == ${ASTROPY_LTS_VERSION}* ]]; then
            echo "The latest stable version of astropy is an LTS version, skipping testing as LTS"
            travis_terminate 0
        fi

        # We add astropy to the pin file to make sure it won't get updated
        echo "astropy ${ASTROPY_LTS_VERSION}*" >> $PIN_FILE
        ASTROPY_OPTION=$ASTROPY_LTS_VERSION
    else
        # We add astropy to the pin file to make sure it won't get updated
        echo "astropy ${ASTROPY_VERSION}*" >> $PIN_FILE
        if [[ $(echo ${ASTROPY_VERSION} | cut -b 1) -ge 3 ]]; then
            ASTROPY_OPTION="$ASTROPY_VERSION pytest-astropy"
        else
            ASTROPY_OPTION=$ASTROPY_VERSION
        fi
    fi
    if [[ ! -z $ASTROPY_OPTION ]]; then
        conda install --no-pin $QUIET python=$PYTHON_VERSION $NUMPY_OPTION astropy=$ASTROPY_OPTION || ( \
            $PIP_FALLBACK && ( \
            echo "Installing astropy with conda was unsuccessful, using pip instead"
            $PIP_INSTALL astropy==$ASTROPY_OPTION
            if [[ -f $PIN_FILE ]]; then
                awk '{if ($1 != "astropy") print $0}' $PIN_FILE > /tmp/pin_file_temp
                mv /tmp/pin_file_temp $PIN_FILE
            fi))
    fi

fi

# SUNPY
if [[ ! -z $SUNPY_VERSION ]]; then
    if [[ $SUNPY_VERSION == dev* ]]; then
        :  # Install at the bottom of the script
    elif [[ $SUNPY_VERSION == pre* ]]; then
        # We use --no-pin to avoid installing other
        conda install --no-pin sunpy
        if [[ -z $(pip list -o --pre | grep sunpy | \
            grep -E "[0-9]rc[0-9]|[0-9][ab][0-9]") ]]; then
            # We want to stop the script if there isn't a pre-release available,
            # as in that case it would be just another build using the stable
            # version.
            echo "Prerelease for sunpy is not available, stopping test"
            travis_terminate 0
        fi
    elif [[ $SUNPY_VERSION == stable ]]; then
        SUNPY_OPTION=$LATEST_SUNPY_STABLE
    else
        # We add sunpy to the pin file to make sure it won't get updated
        echo "sunpy ${SUNPY_VERSION}*" >> $PIN_FILE
        SUNPY_OPTION=$SUNPY_VERSION
    fi
    if [[ ! -z $SUNPY_OPTION ]]; then
        conda install --no-pin $QUIET python=$PYTHON_VERSION $NUMPY_OPTION sunpy=$SUNPY_OPTION || ( \
            $PIP_FALLBACK && ( \
            echo "Installing sunpy with conda was unsuccessful, using pip instead"
            $PIP_INSTALL sunpy==$SUNPY_OPTION
            if [[ -f $PIN_FILE ]]; then
                awk '{if ($1 != "sunpy") print $0}' $PIN_FILE > /tmp/pin_file_temp
                mv /tmp/pin_file_temp $PIN_FILE
            fi))
    fi

fi


# DOCUMENTATION DEPENDENCIES
# build_sphinx needs sphinx and matplotlib (for plot_directive).
if [[ $SETUP_CMD == *build_sphinx* ]] || [[ $SETUP_CMD == *build_docs* ]]; then
    # Check whether there are any version setting env variables, pin them if
    # there are (only need to deal with the case when they aren't listed in
    # CONDA_DEPENDENCIES, otherwise this was already dealt with)

    is_number='[0-9]'
    is_eq_number='=[0-9]'

    if [[ ! -z $MATPLOTLIB_VERSION ]]; then
        if [[ -z $(grep matplotlib $PIN_FILE) ]]; then
            echo "matplotlib ${MATPLOTLIB_VERSION}*" >> $PIN_FILE
        fi
    fi


    # Temporary version limitation due to mpl segfaulting for the docs build
    # (issue tbd). sip needed to be added to the list of packages below to
    # be manually installed so this version pinning actually being taken
    # account
    if [[ -z $SIP_VERSION ]]; then
        echo "sip <4.19" >> $PIN_FILE
    fi

    # Temporary version limitation until
    # https://github.com/sphinx-doc/sphinx/issues/4689 (affecting 1.7) is
    # addressed and a new version of sphinx is released.
    if [[ -z $SPHINX_VERSION ]]; then
        SPHINX_VERSION='<1.7'
    fi

    if [[ ! -z $SPHINX_VERSION ]]; then
        if [[ -z $(grep sphinx $PIN_FILE) ]]; then
            echo "sphinx ${SPHINX_VERSION}*" >> $PIN_FILE
        fi
    fi

    # We don't want to install everything listed in the PIN_FILE in this
    # section, but respect the pinned version of packages that are already
    # installed

    # Adding sip temporarily here, too to take into account the version
    # pinning added above
    conda list > /tmp/installed
    for package in sip matplotlib sphinx; do
        mv $PIN_FILE /tmp/pin_file_copy

        awk -v package=$package '{if ($1 == package) print $0}' /tmp/pin_file_copy > $PIN_FILE
        awk 'FNR==NR{a[$1]=$1;next} $1 in a{print $0}' /tmp/installed /tmp/pin_file_copy >> $PIN_FILE

        $CONDA_INSTALL $package && mv /tmp/pin_file_copy $PIN_FILE || ( \
            $PIP_FALLBACK && (\
            echo "Installing $package with conda was unsuccessful, using pip instead."
            PIP_PACKAGE_VERSION=$(awk '{print $2}' $PIN_FILE)
            if [[ $(echo $PIP_PACKAGE_VERSION | cut -c 1) =~ $is_number ]]; then
                PIP_PACKAGE_VERSION='=='${PIP_${package}_VERSION}
            elif [[ $(echo $PIP_PACKAGE_VERSION | cut -c 1-2) =~ $is_eq_number ]]; then
                PIP_PACKAGE_VERSION='='${PIP_PACKAGE_VERSION}
            fi
            $PIP_INSTALL ${package}${PIP_PACKAGE_VERSION}
            awk -v package=$package '{if ($1 != package) print $0}' /tmp/pin_file_copy > $PIN_FILE
        ))
    done

    if [[ $DEBUG == True ]]; then
        cat $PIN_FILE
    fi

fi

# ADDITIONAL DEPENDENCIES (can include optionals, too)
if [[ ! -z $CONDA_DEPENDENCIES ]]; then
    $CONDA_INSTALL $CONDA_DEPENDENCIES $CONDA_DEPENDENCIES_FLAGS || ( \
        $PIP_FALLBACK && ( \
        # If there is a problem with conda install, try pip install one-by-one
        cp $PIN_FILE /tmp/pin_copy
        for package in $(echo $CONDA_DEPENDENCIES); do
            # We need to avoid other dependencies picked up from the pin file
            awk -v package=$package '{if ($1 == package) print $0}' /tmp/pin_copy > $PIN_FILE
            if [[ $DEBUG == True ]]; then
                cat $PIN_FILE
            fi
            $CONDA_INSTALL $package $CONDA_DEPENDENCIES_FLAGS || ( \
                echo "Installing the dependency $package with conda was unsuccessful, using pip instead."
                # We need to remove the problematic package from the pin
                # file, otherwise further conda install commands may fail,
                # too.
                awk -v package=$package '{if ($1 != package) print $0}' /tmp/pin_copy > /tmp/pin_copy_temp
                mv /tmp/pin_copy_temp /tmp/pin_copy
                $PIP_INSTALL $package);
        done
        mv /tmp/pin_copy $PIN_FILE))
fi

# PARALLEL BUILDS
if [[ $SETUP_CMD == *parallel* || $SETUP_CMD == *numprocesses* ]]; then
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
    $CONDA_INSTALL Cython jinja2 pytest-astropy

    $PIP_INSTALL git+https://github.com/astropy/astropy.git#egg=astropy --upgrade --no-deps
fi

if [[ $ASTROPY_VERSION == pre* ]]; then
    $PIP_INSTALL --pre --upgrade --no-deps astropy
fi

# SUNPY DEV and PRE

# We now install sunpy dev - this has to be done last, otherwise conda might
# install a stable version of sunpy as a dependency to another package, which
# would override sunpy dev. Also, if we are installing Numpy dev, we need to
# compile sunpy dev against Numpy dev. We need to include --no-deps to make
# sure that Numpy doesn't get upgraded.

if [[ $SUNPY_VERSION == dev* ]]; then
    $PIP_INSTALL git+https://github.com/sunpy/sunpy.git#egg=sunpy --upgrade --no-deps
fi

if [[ $SUNPY_VERSION == pre* ]]; then
    $PIP_INSTALL --pre --upgrade --no-deps sunpy
fi



# ASTROPY STABLE

# Due to recent instability in conda, and as new releases are not built in
# astropy-ci-extras, this workaround ensures that we use the latest stable
# version of astropy.

if [[ $ASTROPY_VERSION == stable ]]; then
    old_astropy=$(python -c "from distutils.version import LooseVersion;\
                  import astropy; import os;\
                  print(LooseVersion(astropy.__version__) <\
                  LooseVersion(os.environ['LATEST_ASTROPY_STABLE']))")

    if [[ $old_astropy == True ]]; then
        # First remove astropy from conda to make sure the version installed
        # by pip will be used. We use --force to make sure things that depend
        # on astropy don't cause issues or get uninstalled.
        conda remove astropy --force
        $PIP_INSTALL --upgrade --no-deps --ignore-installed astropy==$LATEST_ASTROPY_STABLE pytest-astropy
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
    # We install requests with conda since it's required by coveralls.
    $CONDA_INSTALL coverage requests
    $PIP_INSTALL coveralls
fi

if [[ $SETUP_CMD == *--cov* ]]; then
    $CONDA_INSTALL pytest-cov
    $PIP_INSTALL coveralls
fi


# SPHINX BUILD MPL FONT CACHING WORKAROUND

# This is required to avoid Sphinx build failures due to a warning that
# comes from the mpl FontManager(). The workaround is to initialize the
# cache before starting the tests/docs build. See details in
# https://github.com/matplotlib/matplotlib/issues/5836

if [[ $SETUP_CMD == *build_sphinx* ]] || [[ $SETUP_CMD == *build_docs* ]]; then
    python -c "import matplotlib.pyplot"
fi

# DEBUG INFO

if [[ $DEBUG == True ]]; then
    # include debug information about the current conda install
    conda install -n root _license
    conda info -a
fi

if [[ ! -z $ASTROPY_VERSION ]]; then
    # Force uninstall hypothesis if it's silently installed as an upstream
    # dependency as the astropy <2.0.3 machinery is incompatible with
    # it. But if it's an explicit dependency in PIP_DEPENDENCIES or
    # CONDA_DEPENDENCIES then we only issue a warning.
    # https://github.com/astropy/astropy/issues/6919

    old_astropy=$(python -c "from distutils.version import LooseVersion;\
                  import astropy; \
                  print(LooseVersion(astropy.__version__) <\
                  LooseVersion('2.0.3'))")
    if [[ $(echo $CONDA_DEPENDENCIES $PIP_DEPENDENCIES | grep hypothesis) ]]; then
        no_explicit_dependency=false
        echo "WARNING: the package 'hypothesis' is incompatible with the Astropy testing mechanism prior version v2.0.3, expect issues during doctesting."
    fi

    if [[ $old_astropy == True ]] && $no_explicit_dependency; then
        conda remove --force hypothesis || true
    fi
fi

set +x
