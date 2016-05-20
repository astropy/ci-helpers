﻿# Sample script to install anaconda under windows
# Authors: Stuart Mumford
# Borrwed from: Olivier Grisel and Kyle Kastner
# License: BSD 3 clause

if (! $env:ASTROPY_LTS_VERSION) {
   $env:ASTROPY_LTS_VERSION = "1.0"
}


# Set environment variables
$env:PATH = "${env:PYTHON};${env:PYTHON}\Scripts;" + $env:PATH

# Conda config
conda config --set always_yes true

if (! $env:CONDA_CHANNELS) {
   $CONDA_CHANNELS=@("astropy", "astropy-ci-extras", "openastronomy")
} else {
   $CONDA_CHANNELS=$env:CONDA_CHANNELS.split(" ")
}
foreach ($CONDA_CHANNEL in $CONDA_CHANNELS) {
   conda config --add channels $CONDA_CHANNEL
}

# Install the build and runtime dependencies of the project.
conda update -q conda

# Create a conda environment using the astropy bonus packages
conda create -q -n test python=$env:PYTHON_VERSION
activate test

# Set environment variables for environment (activate test doesn't seem to do the trick)
$env:PATH = "${env:PYTHON}\envs\test;${env:PYTHON}\envs\test\Scripts;${env:PYTHON}\envs\test\Library\bin;" + $env:PATH

# Check that we have the expected version of Python
python --version

# Check whether a specific version of Numpy is required
if ($env:NUMPY_VERSION) {
    if($env:NUMPY_VERSION -match "stable") {
        $NUMPY_OPTION = "numpy"
    } elseif($env:NUMPY_VERSION -match "dev") {
        $NUMPY_OPTION = "Cython pip".Split(" ")
    } else {
        $NUMPY_OPTION = "numpy=" + $env:NUMPY_VERSION
    }
} else {
    $NUMPY_OPTION = ""
}

# Check whether a specific version of Astropy is required
if ($env:ASTROPY_VERSION) {
    if($env:ASTROPY_VERSION -match "stable") {
        $ASTROPY_OPTION = "astropy"
    } elseif($env:ASTROPY_VERSION -match "dev") {
        $ASTROPY_OPTION = "Cython pip jinja2".Split(" ")
    } elseif($env:ASTROPY_VERSION -match "lts") {
        $ASTROPY_OPTION = "astropy=" + $env:ASTROPY_LTS_VERSION
    } else {
        $ASTROPY_OPTION = "astropy=" + $env:ASTROPY_VERSION
    }
} else {
    $ASTROPY_OPTION = ""
}

# Install the specified versions of numpy and other dependencies
if ($env:CONDA_DEPENDENCIES) {
    $CONDA_DEPENDENCIES = $env:CONDA_DEPENDENCIES.split(" ")
} else {
    $CONDA_DEPENDENCIES = ""
}

# Due to scipy DLL issues with mkl 11.3.3, and as there is no nomkl option
# for windows, we should use mkl 11.3.1 for now as a workaround see discussion
# in https://github.com/astropy/astropy/pull/4907#issuecomment-219200964

if ($NUMPY_OPTION -ne "") {
   $NUMPY_OPTION_mkl = "mkl=11.3.1 " + $NUMPY_OPTION
   echo $NUMPY_OPTION_mkl
   $NUMPY_OPTION = $NUMPY_OPTION_mkl.Split(" ")
}

conda install -n test -q pytest $NUMPY_OPTION $ASTROPY_OPTION $CONDA_DEPENDENCIES

# Check whether the developer version of Numpy is required and if yes install it
if ($env:NUMPY_VERSION -match "dev") {
   Invoke-Expression "${env:CMD_IN_ENV} pip install git+http://github.com/numpy/numpy.git#egg=numpy --upgrade --no-deps"
}

# Check whether the developer version of Astropy is required and if yes install
# it. We need to include --no-deps to make sure that Numpy doesn't get upgraded.
if ($env:ASTROPY_VERSION -match "dev") {
   Invoke-Expression "${env:CMD_IN_ENV} pip install git+http://github.com/astropy/astropy.git#egg=astropy --upgrade --no-deps"
}

# We finally install the dependencies listed in PIP_DEPENDENCIES. We do this
# after installing the Numpy versions of Numpy or Astropy. If we didn't do this,
# then calling pip earlier could result in the stable version of astropy getting
# installed, and then overritten later by the dev version (which would waste
# build time)

if ($env:PIP_FLAGS) {
    $PIP_FLAGS = $env:PIP_FLAGS
} else {
    $PIP_FLAGS = ""
}

if ($env:PIP_DEPENDENCIES) {
    $PIP_DEPENDENCIES = $env:PIP_DEPENDENCIES
} else {
    $PIP_DEPENDENCIES = ""
}

if ($env:PIP_DEPENDENCIES) {
    pip install $PIP_DEPENDENCIES $PIP_FLAGS
}


