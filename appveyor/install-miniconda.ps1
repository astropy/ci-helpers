﻿# Sample script to install anaconda under windows
# Authors: Stuart Mumford
# Borrwed from: Olivier Grisel and Kyle Kastner
# License: BSD 3 clause

$MINICONDA_URL = "http://repo.continuum.io/miniconda/"

if (! $env:ASTROPY_LTS_VERSION) {
   $env:ASTROPY_LTS_VERSION = "1.0"
}

function DownloadMiniconda ($version, $platform_suffix) {
    $webclient = New-Object System.Net.WebClient
    $filename = "Miniconda-" + $version + "-Windows-" + $platform_suffix + ".exe"

    $url = $MINICONDA_URL + $filename

    $basedir = $pwd.Path + "\"
    $filepath = $basedir + $filename
    if (Test-Path $filename) {
        Write-Host "Reusing" $filepath
        return $filepath
    }

    # Download and retry up to 3 times in case of network transient errors.
    Write-Host "Downloading" $filename "from" $url
    $retry_attempts = 2
    for($i=0; $i -lt $retry_attempts; $i++){
        try {
            $webclient.DownloadFile($url, $filepath)
            break
        }
        Catch [Exception]{
            Start-Sleep 1
        }
   }
   if (Test-Path $filepath) {
       Write-Host "File saved at" $filepath
   } else {
       # Retry once to get the error message if any at the last try
       $webclient.DownloadFile($url, $filepath)
   }
   return $filepath
}

function InstallMiniconda ($miniconda_version, $architecture, $python_home) {
    Write-Host "Installing miniconda" $miniconda_version "for" $architecture "bit architecture to" $python_home
    if (Test-Path $python_home) {
        Write-Host $python_home "already exists, skipping."
        return $false
    }
    if ($architecture -eq "x86") {
        $platform_suffix = "x86"
    } else {
        $platform_suffix = "x86_64"
    }
    $filepath = DownloadMiniconda $miniconda_version $platform_suffix
    Write-Host "Installing" $filepath "to" $python_home
    $args = "/InstallationType=AllUsers /S /AddToPath=1 /RegisterPython=1 /D=" + $python_home
    Write-Host $filepath $args
    Start-Process -FilePath $filepath -ArgumentList $args -Wait -Passthru
    #Start-Sleep -s 15
    if (Test-Path $python_home) {
        Write-Host "Miniconda $miniconda_version ($architecture) installation complete"
    } else {
        Write-Host "Failed to install Python in $python_home"
        Exit 1
    }
}

# Install miniconda
InstallMiniconda $env:MINICONDA_VERSION $env:PLATFORM $env:PYTHON

# Set environment variables
$env:PATH = "${env:PYTHON};${env:PYTHON}\Scripts;" + $env:PATH

# Conda config
conda config --set always_yes true

if (! $env:CONDA_CHANNELS) {
   $CONDA_CHANNELS=@("astropy", "astropy-ci-extras")
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
    } elseif ($env:NUMPY_VERSION -match "pre") {
        $NUMPY_OPTION = "numpy"
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
    } elseif ($env:ASTROPY_VERSION -match "pre") {
        $ASTROPY_OPTION = "astropy"
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

conda install -n test -q pytest $NUMPY_OPTION $ASTROPY_OPTION $CONDA_DEPENDENCIES

# Check whether the developer version of Numpy is required and if yes install it
if ($env:NUMPY_VERSION -match "dev") {
   Invoke-Expression "${env:CMD_IN_ENV} pip install git+http://github.com/numpy/numpy.git#egg=numpy --upgrade --no-deps"
}

# Check whether a pre-release version of Numpy is required check whether a
# pre-release is available, and upgrade to it from the stable version. If
# there is no pre-release we should exit the script without running the
# tests:

if ($env:NUMPY_VERSION -match "pre") {
   if (Invoke-Expression "${env:CMD_IN_ENV} pip list -o --pre | grep numpy | grep -E '[0-9]rc[0-9]|[0-9][ab][0-9]'") {
      Invoke-Expression "${env:CMD_IN_ENV} pip install --pre --upgrade --no-deps numpy"
   }
   else { EXIT 0 }
}

# Check whether the developer version of Astropy is required and if yes install
# it. We need to include --no-deps to make sure that Numpy doesn't get upgraded.

if ($env:ASTROPY_VERSION -match "dev") {
   Invoke-Expression "${env:CMD_IN_ENV} pip install git+http://github.com/astropy/astropy.git#egg=astropy --upgrade --no-deps"
}

# Check whether a pre-release version of Astropy is required check whether a
# pre-release is available, and upgrade to it from the stable version. If
# there is no pre-release we should exit the script without running the
# tests:

if ($env:ASTROPY_VERSION -match "pre") {
   if (Invoke-Expression "${env:CMD_IN_ENV} pip list -o --pre | grep astropy | grep -E '[0-9]rc[0-9]|[0-9][ab][0-9]'") {
      Invoke-Expression "${env:CMD_IN_ENV} pip install --pre --upgrade --no-deps numpy"
   }
   else { EXIT 0 }
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


