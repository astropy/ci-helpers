#!/bin/bash -x

hash -r

set -e


# If not set from outside, initialize parameters for the retry_on_known_error()
# function:

# If a command wrapped by the 'retry_on_known_error' function fails, its output
# (stdout and stderr) is parsed for the strings in RETRY_ERRORS and scheduled
# for retry if any of the strings is found.
if [ -z "$RETRY_ERRORS" ]; then
    RETRY_ERRORS="CondaHTTPError" # add more errors if needed (space-separated)
fi

# Maximum number of retries:
if [ -z "$RETRY_MAX" ]; then
    RETRY_MAX=3
fi

# Delay before retrying in seconds:
if [ -z "$RETRY_DELAY" ]; then
    RETRY_DELAY=2
fi

# A wrapper for calls that should be repeated if their output contains any of
# the strings in RETRY_ERRORS.
##############################################################################
# CAUTION: This function will *unify* stdout and stderr of the wrapped call: #
#          In case of success, the call's entire output will go to stdout.   #
#          In case of failure, the call's entire output will go to stderr.   #
##############################################################################
function retry_on_known_error() {
    if [ -z "$*" ]; then
        echo "ERROR: Function retry_on_known_error() called without arguments." 1>&2
        return 1
    fi
    _tmp_output_file="tmp.txt"
    _n_retries=0
    _exitval=0
    _retry=true
    while $_retry; do
        _retry=false
        # Execute the wrapped command and get its unified output.
        # This command needs to run in the current shell/environment in case
        # it sets environment variables (like 'conda install' does)
        #
        # tee will both echo output to stdout and save it in a file. The file
        # is needed for some error checks later. Output to stdout is needed in
        # the event a conda solve takes a really long time (>10 min). If
        # there is no output on travis for that long, the job is cancelled.
        set +e
        $@ > $_tmp_output_file 2>&1
        _exitval="$?"
        # Keep the cat here...otherwise _exitval is always 0
        # even if the conda install failed.
        cat $_tmp_output_file
        set -e

        # The hack below is to work around a bug in conda 4.7 in which a spec
        # pinned in a pin file is not respected if that package is listed
        # explicitly on the command line even if there is no version spec on
        # the command line. See:
        #
        #   https://github.com/conda/conda/issues/9052
        #
        # The hacky workaround is to identify overridden specs and add the
        # spec from the pin file back to the command line.
        if [[ -n $(grep "conflicts with explicit specs" $_tmp_output_file) ]]; then
            # Roll back the command than generated the conflict message.
            # To do this, we get the most recent environment revision number,
            # then roll back to the one before that.
            # To ensure we don't need to activate, direct output of conda to
            # a file instead of piping
            _revision_file="revisions.txt"
            conda list --revision > _revision_file
            _current_revision=$(cat _revision_file | grep \(rev | tail -1 | cut -d' ' -f5 | cut -d')' -f1)
            conda install --revision=$(( $_current_revision - 1 ))
            _tmp_spec_conflicts=bad_spec.txt
            # Isolate the problematic specs
            grep "conflicts with explicit specs" $_tmp_output_file > $_tmp_spec_conflicts

            # Do NOT turn the three lines below into one by putting the python in a
            # $()...we need to make sure we stay in the shell in which conda is activated,
            # not a subshell.
            _tmp_updated_conda_command=new_command.txt
            python ci-helpers/travis/hack_version_numbers.py $_tmp_spec_conflicts "$@" > $_tmp_updated_conda_command
            revised_command=$(cat $_tmp_updated_conda_command)
            echo $revised_command
            # Try it; if it still has conflicts then just give up
            $revised_command > $_tmp_output_file 2>&1
            _exitval="$?"
            # Keep the cat here...otherwise _exitval is always 0
            # even if the conda install failed.
            cat $_tmp_output_file
            if [[ -n $(grep "conflicts with explicit specs" $_tmp_output_file) ]]; then
                echo "STOPPING conda attempts because unable to resolve conda pinning issues"
                rm -f $_tmp_output_file
                return 1
            fi
        fi

        # If the command was sucessful, abort the retry loop:
        if [ "$_exitval" == "0" ]; then
            break
        fi

        # The command errored, so let's check its output for the specified error
        # strings:
        if [[ $_n_retries -lt $RETRY_MAX ]]; then
            # If a known error string was found, throw a warning and wait a
            # certain number of seconds before invoking the command again:
            for _error in $RETRY_ERRORS; do
                if [ -n "$(grep "$_error" "$_tmp_output_file")" ]; then
                    echo "WARNING: The comand \"$@\" failed due to a $_error, retrying." 1>&2
                    _n_retries=$(($_n_retries + 1))
                    _retry=true
                    sleep $RETRY_DELAY
                    break
                fi
            done
        fi
    done
    # remove the temporary output file
    rm -f "$_tmp_output_file"
    # Finally, return the command's exit code:
    return $_exitval
}

# We need to do this before updating conda, as $CONDA_CHANNELS may be a
# conda environment variable for some Miniconda versions, too that needs to
# be space separated.
if [[ ! -z $CONDA_CHANNELS ]]; then
    for channel in $CONDA_CHANNELS; do
        conda config --add channels $channel
    done
fi

# This used to be in the conditional above, but even if empty it shouldn't
# be passed to conda.
unset CONDA_CHANNELS

conda config --set always_yes yes --set changeps1 no

shopt -s nocasematch

if [[ -z $PYTHON_VERSION ]]; then
    export PYTHON_VERSION=$TRAVIS_PYTHON_VERSION
fi

# We will use the 2.0.x releases as "stable" for Python 2.7 and 3.4
if [[ $(python -c "from distutils.version import LooseVersion; import os;\
        print(LooseVersion(os.environ['PYTHON_VERSION']) < '3.5')") == False ]]; then
    export LATEST_ASTROPY_STABLE=4.0
    export LATEST_NUMPY_STABLE=1.18
else
    export LATEST_ASTROPY_STABLE=2.0.16
    export NO_PYTEST_ASTROPY=True
    export LATEST_NUMPY_STABLE=1.16
fi
export ASTROPY_LTS_VERSION=2.0.16
export LATEST_SUNPY_STABLE=1.0.6


is_number='[0-9]'
is_eq_number='=[0-9]'
is_eq_float="=[0-9]+\.[0-9]+"


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
    CONDA_VERSION=4.7.11
fi

if [[ -z $PIN_FILE_CONDA ]]; then
    PIN_FILE_CONDA=$HOME/miniconda/conda-meta/pinned
fi

echo "conda ${CONDA_VERSION}" > $PIN_FILE_CONDA

retry_on_known_error conda install $QUIET conda

if [[ -z $CONDA_CHANNEL_PRIORITY ]]; then
    CONDA_CHANNEL_PRIORITY=disabled
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

# Making sure we don't upgrade python accidentally
if [[ ! -z $PYTHON_VERSION ]]; then
    PYTHON_OPTION="python=$PYTHON_VERSION"
else
    PYTHON_OPTION=""
fi

# Setting the MPL backend to a default to avoid occational segfaults with the qt backend
if [[ -z $MPLBACKEND ]]; then
    export MPLBACKEND=Agg
fi


# Python 3.4 is only available on conda's "free" channel, which was removed in
# conda 4.7.
if [[ $PYTHON_VERSION == 3.4* ]]; then
    conda config --set restore_free_channel true
fi


# CONDA
if [[ -z $CONDA_ENVIRONMENT ]]; then
    retry_on_known_error conda create $QUIET -n test $PYTHON_OPTION
else
    retry_on_known_error conda env create $QUIET -n test -f $CONDA_ENVIRONMENT
fi
conda activate test

# PIN FILE
if [[ -z $PIN_FILE ]]; then
    PIN_FILE=$HOME/miniconda/envs/test/conda-meta/pinned
fi

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
    echo "pytest ${PYTEST_VERSION}.*" >> $PIN_FILE
fi

if [[ ! -z $PIP_VERSION ]]; then
    echo "pip ${PIP_VERSION}.*" >> $PIN_FILE
fi

export PIP_INSTALL='python -m pip install'

retry_on_known_error conda install --no-channel-priority $QUIET $PYTHON_OPTION pytest pip || { \
    $PIP_FALLBACK && { \
    if [[ ! -z $PYTEST_VERSION ]]; then
        echo "Installing pytest with conda was unsuccessful, using pip instead"
        retry_on_known_error conda install $QUIET $PYTHON_OPTION pip
        if [[ $(echo $PYTEST_VERSION | cut -c 1) =~ $is_number ]]; then
            PIP_PYTEST_VERSION='=='${PYTEST_VERSION}.*
        elif [[ $(echo $PYTEST_VERSION | cut -c 1-2) =~ $is_eq_number ]]; then
            PIP_PYTEST_VERSION='='${PYTEST_VERSION}
        else
            PIP_PYTEST_VERSION=${PYTEST_VERSION}
        fi
        $PIP_INSTALL pytest${PIP_PYTEST_VERSION}
        awk '{if ($1 != "pytest") print $0}' $PIN_FILE > /tmp/pin_file_temp
        mv /tmp/pin_file_temp $PIN_FILE
    fi;}
}

# In case of older python versions there isn't an up-to-date version of pip
# which may lead to ignore install dependencies of the package we test.
# This update should not interfere with the rest of the functionalities
# here.
#
# This *may* be leading to inconsistent conda environments, definitely means
# that conda is not aware of pip installs, and is often overridden by
# subsequent conda installs because conda is configured to install pip by
# default now.
#
# For really old pythons it may be necessary, though, so check pip version and
# install this way if the major version is less than 19.
if [[ -z $PIP_VERSION ]]; then
    old_pip=$(python -c "from distutils.version import LooseVersion;\
                import os; import pip;\
                print(LooseVersion(pip.__version__) <\
                      LooseVersion('19.0.0'))")
    if [[ $old_pip == True ]]; then
        $PIP_INSTALL --upgrade pip
    fi
fi

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
# https://docs.conda.io/projects/conda/en/latest/user-guide/tasks/manage-pkgs.html#preventing-packages-from-updating-pinning
if [[ ! -z $CONDA_DEPENDENCIES ]]; then

    if [[ -z $(echo $CONDA_DEPENDENCIES | grep '\bmkl\b') &&
            $TRAVIS_OS_NAME != windows && ! -z $NUMPY_VERSION ]]; then
        CONDA_DEPENDENCIES=${CONDA_DEPENDENCIES}" nomkl"
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
        if [[ ! -z $version && ($version != dev* && $version != pre*) ]]; then
            awk -v package=$package -v version=$version \
                '{if ($1 == package) print package" " version".*";
                  else print $0}' \
                $PIN_FILE > /tmp/pin_file_temp
            mv /tmp/pin_file_temp $PIN_FILE
       fi
    done

    # Do in the pin file what conda silently does on the command line, to
    # extend the underspecified version numbers with *
    awk -F == '{if (NF==1) print $0; else print $1, $2".*"}' \
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

if [[ ! -z $CONDA_DEPENDENCIES ]]; then
    # Do a dry run of the conda install here to make sure that pins are
    # ACTUALLY being respected. This will become unnecessary when
    # https://github.com/conda/conda/issues/9052
    # is fixed

    # NOTE: it is important that the expression below remain in an if context
    # because of the 'set -e' above, which causes the shell to immediately
    # exit if the last command in a pipeline has a non-zero exit status,
    # UNLESS the pipeline is in a few specific contexts.  From
    # https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html:
    #
    #     The shell does not exit if the command that fails is ...part of the
    #     test in an if statement...
    #
    # Use tee to print output to console and to file to avoid travis timing out
    _tmp_output_file="tmp.txt"
    # do not exit on failure of the dry run because pip fallback may succeed
    set +e
    conda install --dry-run $CONDA_DEPENDENCIES > $_tmp_output_file 2>&1
    cat $_tmp_output_file
    set -e
    # 'grep' returns non-zero exit status if no lines match.
    if [[ ! -z $(grep "conflicts with explicit specs" $_tmp_output_file) ]]; then
        echo "restoring free channel"
        # Restoring the free channel only helps if the channel priority
        # is not strict, so check that first. If it is strict, fail instead
        # of changing the solve logic.

        # ...but only if the free channel is not ruled out by strict
        # channel priority
        if [[ $CONDA_CHANNEL_PRIORITY == strict ]]; then
            # If the channel priority is strict we should fail instead of silently
            # changing how the solve is done.
            echo "WARNING: May not be able to solve this environment with pinnings and strict channel priority"
            # Keep going, because retry_on_known_errors now checks for pinning
            # problems and will trigger a pip fallback if they continue.
        fi
        # Add the free channel, which might fix this...
        conda config --set restore_free_channel true

        # Try the dry run again, fail if pinnings are still ignored
        echo "Re-running with free channel restored"

        # do not exit on failure of the dry run because pip fallback may succeed
        set +e
        conda install --dry-run $CONDA_DEPENDENCIES > >(tee $_tmp_output_file) 2>&1
        set -e
        if [[ ! -z $(grep "conflicts with explicit specs" $_tmp_output_file) ]]; then
            # No clue how to fix this, so just give up
            echo "WARNING: conda is ignoring pinnings"
            # Actually, just continue. retry_on_known_errors now checks for
            # pinning problems and will trigger a pip fallback if they continue.
        fi
    fi

    # Clean up
    rm -f $_tmp_output_file
fi

# NUMPY

# Older versions of numpy are only available on the "free" channel, which
# has been removed as of conda 4.7 from the list of default channels.
# This adds it back if needed.

if [[ ! -z $NUMPY_VERSION ]]; then
    # We only want to do a check for old versions of numpy, not for dev or stable
    if [[ $NUMPY_VERSION =~ [0-9]+(\.[0-9]){1,2} ]]; then
        old_numpy=$(python -c "from distutils.version import LooseVersion;\
                    import os;\
                    print(LooseVersion(os.environ['NUMPY_VERSION']) <\
                          LooseVersion('1.11.0'))")
        if [[ $old_numpy == True ]]; then
            conda config --set restore_free_channel true
        fi
    fi
fi

# We use --no-pin to avoid installing other dependencies just yet.


MKL='nomkl'
if [[ ! -z $(echo $CONDA_DEPENDENCIES | grep '\bmkl\b') ||
        $TRAVIS_OS_NAME == windows || -z $NUMPY_VERSION ]]; then
    MKL=''
fi

# determine how to install numpy:
NUMPY_INSTALL=''
if [[ $NUMPY_VERSION == dev* ]]; then
    # We use C99 to build Numpy.
    # If CFLAGS already defined by calling pkg, it's up to them to set this.
    if [[ -z $CFLAGS ]]; then
        export CFLAGS="-std=c99"
    fi
    # We install nomkl here to make sure that Numpy and Scipy versions
    # installed subsequently don't depend on the MKL. If we don't do this, then
    # we run into issues when we install the developer version of Numpy
    # because it is then not compiled against the MKL, and one runs into issues
    # if Scipy *is* still compiled against the MKL.
    retry_on_known_error conda install $QUIET --no-pin $PYTHON_OPTION $MKL
    # We then install Numpy itself at the bottom of this script
    export CONDA_INSTALL="conda install $QUIET $PYTHON_OPTION $MKL"
elif [[ $NUMPY_VERSION == stable ]]; then
    export NUMPY_OPTION="numpy=$LATEST_NUMPY_STABLE"
    export CONDA_INSTALL="conda install $QUIET $PYTHON_OPTION $NUMPY_OPTION $MKL"
    NUMPY_INSTALL="conda install $QUIET --no-pin $PYTHON_OPTION $NUMPY_OPTION $MKL"
elif [[ $NUMPY_VERSION == pre* ]]; then
    export NUMPY_OPTION=""
    export CONDA_INSTALL="conda install $QUIET $PYTHON_OPTION $MKL"
    NUMPY_INSTALL="conda install $QUIET --no-pin $PYTHON_OPTION $MKL numpy"
    if [[ -z $(pip list -o --pre | grep numpy | \
            grep -E "[0-9]rc[0-9]|[0-9][ab][0-9]") ]]; then
        # We want to stop the script if there isn't a pre-release available,
        # as in that case it would be just another build using the stable
        # version.
        echo "Prerelease for numpy is not available, stopping test"
        travis_terminate 0
    fi
elif [[ ! -z $NUMPY_VERSION ]]; then
    export NUMPY_OPTION="numpy=$NUMPY_VERSION"
    export CONDA_INSTALL="conda install $QUIET $PYTHON_OPTION $NUMPY_OPTION $MKL"
    NUMPY_INSTALL="conda install $QUIET --no-pin $PYTHON_OPTION $NUMPY_OPTION $MKL"

else
    export NUMPY_OPTION=""
    export CONDA_INSTALL="conda install $QUIET $PYTHON_OPTION $MKL"
fi

# try to install numpy:
if [[ ! -z $NUMPY_INSTALL ]]; then
    retry_on_known_error $NUMPY_INSTALL || { \
        if [[ -z $NUMPY_OPTION ]]; then
            PIP_NUMPY_OPTION="numpy"
        else
            # add wildcard for float-like version specs:
            if [[ $NUMPY_OPTION =~ ^numpy$is_eq_float$ ]]; then
                PIP_NUMPY_OPTION="numpy==${NUMPY_OPTION#*=}.*"
            # use exact version definitions as is:
            elif [[ $NUMPY_OPTION =~ ^numpy=.* ]]; then
                PIP_NUMPY_OPTION="numpy==${NUMPY_OPTION#numpy=}"
            # Should version specs with 'numpy>=X' etc. ever be used,
            # use these as is:
            else
                PIP_NUMPY_OPTION="$NUMPY_OPTION"
            fi
        fi
        echo -e "\nInstalling $NUMPY_OPTION with conda was unsuccessful," \
                "removing from conda install and adding $PIP_NUMPY_OPTION" \
                " to PIP_DEPENDENCIES instead.\n"
        export PIP_DEPENDENCIES="$PIP_DEPENDENCIES $PIP_NUMPY_OPTION"
        # now that numpy will be installed via pip later,
        # remove it from CONDA_INSTALL:
        export CONDA_INSTALL=$(echo $CONDA_INSTALL | sed -e 's/numpy[a-zA-Z0-9.=]*\( \|$\)//g')
    }
fi

# ASTROPY
if [[ ! -z $ASTROPY_VERSION ]]; then
    if [[ $ASTROPY_VERSION == dev* ]]; then
        : # Install at the bottom of this script
    elif [[ $ASTROPY_VERSION == pre* ]]; then
        # We use --no-pin to avoid installing other dependencies just yet
        retry_on_known_error conda install --no-pin $PYTHON_OPTION astropy
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
        echo "astropy ${LATEST_ASTROPY_STABLE}.*" >> $PIN_FILE

        if [[ $NO_PYTEST_ASTROPY == True ]]; then
            ASTROPY_OPTION="$LATEST_ASTROPY_STABLE"
        else
            ASTROPY_OPTION="$LATEST_ASTROPY_STABLE pytest-astropy"
        fi

    elif [[ $ASTROPY_VERSION == lts ]]; then
        # We add astropy to the pin file to make sure it won't get updated
        echo "astropy ${ASTROPY_LTS_VERSION}.*" >> $PIN_FILE
        ASTROPY_OPTION=$ASTROPY_LTS_VERSION
    else
        # We add astropy to the pin file to make sure it won't get updated
        echo "astropy ${ASTROPY_VERSION}.*" >> $PIN_FILE
        if [[ $(echo ${ASTROPY_VERSION} | cut -b 1) -ge 3 ]]; then
            ASTROPY_OPTION="$ASTROPY_VERSION pytest-astropy"
        else
            ASTROPY_OPTION=$ASTROPY_VERSION
        fi
    fi
    if [[ ! -z $ASTROPY_OPTION ]]; then
        retry_on_known_error conda install --no-pin $QUIET $PYTHON_OPTION $NUMPY_OPTION astropy=$ASTROPY_OPTION || { \
            $PIP_FALLBACK && { \
            echo "Installing astropy with conda was unsuccessful, using pip instead"
            $PIP_INSTALL astropy==$ASTROPY_OPTION
            if [[ -f $PIN_FILE ]]; then
                awk '{if ($1 != "astropy") print $0}' $PIN_FILE > /tmp/pin_file_temp
                mv /tmp/pin_file_temp $PIN_FILE
            fi;};}
    fi

fi

# SUNPY
if [[ ! -z $SUNPY_VERSION ]]; then
    if [[ $SUNPY_VERSION == dev* ]]; then
        :  # Install at the bottom of the script
    elif [[ $SUNPY_VERSION == pre* ]]; then
        # We use --no-pin to avoid installing other
        retry_on_known_error conda install --no-pin $PYTHON_OPTION sunpy
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
        echo "sunpy ${SUNPY_VERSION}.*" >> $PIN_FILE
        SUNPY_OPTION=$SUNPY_VERSION
    fi
    if [[ ! -z $SUNPY_OPTION ]]; then
        retry_on_known_error conda install --no-pin $QUIET $PYTHON_OPTION $NUMPY_OPTION sunpy=$SUNPY_OPTION || { \
            $PIP_FALLBACK && { \
            echo "Installing sunpy with conda was unsuccessful, using pip instead"
            $PIP_INSTALL sunpy==$SUNPY_OPTION
            if [[ -f $PIN_FILE ]]; then
                awk '{if ($1 != "sunpy") print $0}' $PIN_FILE > /tmp/pin_file_temp
                mv /tmp/pin_file_temp $PIN_FILE
            fi;};}
    fi

fi


# DOCUMENTATION DEPENDENCIES
# build_sphinx needs sphinx and matplotlib (for plot_directive).
if [[ $SETUP_CMD == *build_sphinx* ]] || [[ $SETUP_CMD == *build_docs* ]]; then
    # Check whether there are any version setting env variables, pin them if
    # there are (only need to deal with the case when they aren't listed in
    # CONDA_DEPENDENCIES, otherwise this was already dealt with)

    if [[ ! -z $MATPLOTLIB_VERSION ]]; then
        if [[ -z $(grep matplotlib $PIN_FILE) ]]; then
            echo "matplotlib ${MATPLOTLIB_VERSION}.*" >> $PIN_FILE
        fi
    fi


    # Temporary version limitation due to mpl segfaulting for the docs build
    # (issue tbd). sip needed to be added to the list of packages below to
    # be manually installed so this version pinning actually being taken
    # account
    if [[ -z $SIP_VERSION ]]; then
        echo "sip <4.19" >> $PIN_FILE
    fi

    if [[ ! -z $SPHINX_VERSION ]]; then
        if [[ -z $(grep sphinx $PIN_FILE) ]]; then
            echo "sphinx ${SPHINX_VERSION}.*" >> $PIN_FILE
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

        retry_on_known_error $CONDA_INSTALL $package && mv /tmp/pin_file_copy $PIN_FILE || { \
            $PIP_FALLBACK && { \
            echo "Installing $package with conda was unsuccessful, using pip instead."
            PIP_PACKAGE_VERSION=$(grep $package $PIN_FILE | awk '{print $2}')
            # Debugging....
            echo "WHAT IS GOING ON HERE (TAKE 2)"
            conda info -a
            conda config --show
            conda list
            cat $PIN_FILE
            if [[ $(echo $PIP_PACKAGE_VERSION | cut -c 1) =~ $is_number ]]; then
                PIP_PACKAGE_VERSION='=='${PIP_PACKAGE_VERSION}
            elif [[ $(echo $PIP_PACKAGE_VERSION | cut -c 1-2) =~ $is_eq_number ]]; then
                PIP_PACKAGE_VERSION='='${PIP_PACKAGE_VERSION}
            fi
            $PIP_INSTALL ${package}${PIP_PACKAGE_VERSION}
            awk -v package=$package '{if ($1 != package) print $0}' /tmp/pin_file_copy > $PIN_FILE
        };}
    done

    if [[ $DEBUG == True ]]; then
        cat $PIN_FILE
    fi

fi

# ADDITIONAL DEPENDENCIES (can include optionals, too)
if [[ ! -z $CONDA_DEPENDENCIES ]]; then
    retry_on_known_error $CONDA_INSTALL $CONDA_DEPENDENCIES $CONDA_DEPENDENCIES_FLAGS || { \
        $PIP_FALLBACK && { \
        # If there is a problem with conda install, try pip install one-by-one
        cp $PIN_FILE /tmp/pin_copy
        for package in $(echo $CONDA_DEPENDENCIES); do
            # We need to avoid other dependencies picked up from the pin file
            awk -v package=$package '{if ($1 == package) print $0}' /tmp/pin_copy > $PIN_FILE
            if [[ $DEBUG == True ]]; then
                cat $PIN_FILE
            fi
            retry_on_known_error $CONDA_INSTALL $package $CONDA_DEPENDENCIES_FLAGS || { \
                echo "Installing the dependency $package with conda was unsuccessful, using pip instead."
                # We need to remove the problematic package from the pin
                # file, otherwise further conda install commands may fail,
                # too. Also we may need to limit the version installed by pip.
                PIP_PACKAGE_VERSION=$(awk '{print $2}' $PIN_FILE)

                # Deal with as for specific version, otherwise the limitation can be passed on as is
                if [[ $(echo $PIP_PACKAGE_VERSION | cut -c 1) =~ $is_number ]]; then
                    PIP_PACKAGE_VERSION='=='${PIP_PACKAGE_VERSION}
                elif [[ $(echo $PIP_PACKAGE_VERSION | cut -c 1-2) =~ $is_eq_number ]]; then
                    PIP_PACKAGE_VERSION='='${PIP_PACKAGE_VERSION}
                fi
                awk -v package=$package '{if ($1 != package) print $0}' /tmp/pin_copy > /tmp/pin_copy_temp
                mv /tmp/pin_copy_temp /tmp/pin_copy
                $PIP_INSTALL $package${PIP_PACKAGE_VERSION};};
        done
        mv /tmp/pin_copy $PIN_FILE;};}
fi

# PARALLEL BUILDS
if [[ $SETUP_CMD == *parallel* || $SETUP_CMD == *numprocesses* ]]; then
    $PIP_INSTALL pytest-xdist
fi

# OPEN FILES
if [[ $SETUP_CMD == *open-files* ]]; then
    retry_on_known_error $CONDA_INSTALL psutil
fi

# NUMPY DEV and PRE

# We now install Numpy dev - this has to be done last, otherwise conda might
# install a stable version of Numpy as a dependency to another package, which
# would override Numpy dev or pre.

if [[ $NUMPY_VERSION == dev* ]]; then
    retry_on_known_error conda install $QUIET Cython
    $PIP_INSTALL git+https://github.com/numpy/numpy.git#egg=numpy --upgrade --no-deps
fi

if [[ $NUMPY_VERSION == pre* ]]; then
    $PIP_INSTALL --pre --upgrade numpy
fi

# MATPLOTLIB DEV

# We now install Matplotlib dev - this has to be done last, otherwise conda might
# install a stable version of matplotlib as a dependency to another package, which
# would override matplotlib dev.

if [[ $MATPLOTLIB_VERSION == dev* ]]; then
    $PIP_INSTALL git+https://github.com/matplotlib/matplotlib.git#egg=matplotlib --upgrade --no-deps
fi

if [[ $MATPLOTLIB_VERSION == pre* ]]; then
    $PIP_INSTALL --pre --upgrade --no-deps matplotlib
fi


# SCIPY_DEV

# We now install Scipy dev - this has to be done last, otherwise conda might
# install a stable version of matplotlib as a dependency to another package, which
# would override matplotlib dev.

if [[ $SCIPY_VERSION == dev* ]]; then
    retry_on_known_error $CONDA_INSTALL Cython

    $PIP_INSTALL git+https://github.com/scipy/scipy.git#egg=scipy --upgrade --no-deps
fi

if [[ $SCIPY_VERSION == pre* ]]; then
    $PIP_INSTALL --pre --upgrade --no-deps scipy
fi


# SCIKIT_LEARN DEV

# We now install scikit-learn dev - this has to be done last, otherwise conda might
# install a stable version of matplotlib as a dependency to another package, which
# would override matplotlib dev.

if [[ $SCIKIT_LEARN_VERSION == dev* ]]; then
    retry_on_known_error $CONDA_INSTALL Cython

    $PIP_INSTALL git+https://github.com/scikit-learn/scikit-learn.git#egg=sklearn --upgrade --no-deps
fi

if [[ $SCIKIT_LEARN_VERSION == pre* ]]; then
    $PIP_INSTALL --pre --upgrade --no-deps scikit-learn
fi

# ASTROPY DEV and PRE

# We now install Astropy dev - this has to be done last, otherwise conda might
# install a stable version of Astropy as a dependency to another package, which
# would override Astropy dev. Also, if we are installing Numpy dev, we need to
# compile Astropy dev against Numpy dev. We need to include --no-deps to make
# sure that Numpy doesn't get upgraded.

if [[ $ASTROPY_VERSION == dev* ]]; then
    $PIP_INSTALL Cython jinja2 pytest-astropy
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

# Due to recent instability in conda, this workaround ensures that we use the
# latest stable version of astropy.

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
    retry_on_known_error $CONDA_INSTALL coverage requests
    $PIP_INSTALL coveralls codecov
fi

if [[ $SETUP_CMD == *-cov* ]]; then
    $PIP_INSTALL coveralls codecov pytest-cov
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
    # There was once an install of a _license package here, which does not
    # exist for python >=3.7
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

set +ex
