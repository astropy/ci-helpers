#!/bin/bash -ex

# Script to set up Python using native platform tools rather than conda

echo "==================== Starting executing ci-helpers scripts ====================="

if [[ -z $PYTHON_VERSION ]]; then
    echo "PYTHON_VERSION needs to be set";
    exit 1;
fi

if [[ $PYTHON_VERSION == 3.6 ]]; then
    FULL_PYTHON_VERSION=3.6.8;
elif [[ $PYTHON_VERSION == 3.7 ]]; then
    FULL_PYTHON_VERSION=3.7.9;
elif [[ $PYTHON_VERSION == 3.8 ]]; then
    FULL_PYTHON_VERSION=3.8.6;
elif [[ $PYTHON_VERSION == 3.9 ]]; then
    FULL_PYTHON_VERSION=3.9.0;
fi

if [[ $TRAVIS_OS_NAME == windows ]]; then
    CONDENSED_PYTHON_VERSION="${PYTHON_VERSION//.}"
    choco install --no-progress python --version $FULL_PYTHON_VERSION;
    export PATH="/c/Python$CONDENSED_PYTHON_VERSION:/c/Python$CONDENSED_PYTHON_VERSION/Scripts:$PATH"
    python -m venv ~/python;
    source ~/python/Scripts/activate;
    python -m pip install --upgrade pip;
fi

if [[ $TRAVIS_OS_NAME == osx ]]; then

    wget https://www.python.org/ftp/python/$FULL_PYTHON_VERSION/python-$FULL_PYTHON_VERSION-macosx10.9.pkg
    sudo installer -pkg python-$FULL_PYTHON_VERSION-macosx10.9.pkg -target /
    /Applications/Python\ $PYTHON_VERSION/Install\ Certificates.command
    python$PYTHON_VERSION -m venv ~/python;
    source ~/python/bin/activate;
    python -m pip install --upgrade pip;
fi

echo "Checking default python version:"
echo `python --version`

echo "================= Returning executing local .travis.yml script ================="
