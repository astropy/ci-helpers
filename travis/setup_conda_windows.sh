#!/bin/bash
# This script assumes we are running under git-bash (MinGW) on Windows

if [[ -z "${MINICONDA_VERSION}" ]]; then
    MINICONDA_VERSION=4.5.4
fi

# wget is not necessarily present, so use curl
curl https://repo.continuum.io/miniconda/Miniconda3-${MINICONDA_VERSION}-Windows-x86_64.exe > miniconda.exe

curdir=`pwd`
installer_args="//InstallationType=AllUsers //S //AddToPath=1 //RegisterPython=1"
./miniconda.exe "$installer_args //D=\"$curdir\""
export PATH="$curdir/Miniconda3:$PATH"

# Install common Python dependencies
source "$( dirname "${BASH_SOURCE[0]}" )"/setup_dependencies_common.sh
