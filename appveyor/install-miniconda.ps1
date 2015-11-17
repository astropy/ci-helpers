﻿# Sample script to install anaconda under windows
# Authors: Stuart Mumford
# Borrwed from: Olivier Grisel and Kyle Kastner
# License: BSD 3 clause

$MINICONDA_URL = "http://repo.continuum.io/miniconda/"

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

function InstallMiniconda ($python_version, $architecture, $python_home) {
    Write-Host "Installing miniconda" $python_version "for" $architecture "bit architecture to" $python_home
    if (Test-Path $python_home) {
        Write-Host $python_home "already exists, skipping."
        return $false
    }
    if ($architecture -eq "x86") {
        $platform_suffix = "x86"
    } else {
        $platform_suffix = "x86_64"
    }
    $filepath = DownloadMiniconda $python_version $platform_suffix
    Write-Host "Installing" $filepath "to" $python_home
    $args = "/InstallationType=AllUsers /S /AddToPath=1 /RegisterPython=1 /D=" + $python_home
    Write-Host $filepath $args
    Start-Process -FilePath $filepath -ArgumentList $args -Wait -Passthru
    #Start-Sleep -s 15
    if (Test-Path C:\conda) {
        Write-Host "Miniconda $python_version ($architecture) installation complete"
    } else {
        Write-Host "Failed to install Python in $python_home"
        Exit 1
    }
}

# Install miniconda
InstallMiniconda $env:MINICONDA_VERSION $env:PLATFORM $env:PYTHON

# Set environment variables
$env:PATH = "C:\conda;C:\conda\Scripts;" + $env:PATH

# Conda config
conda config --set always_yes true
conda config --add channels astropy-ci-extras

# Install the build and runtime dependencies of the project.
conda update -q conda

# Create a conda environment using the astropy bonus packages
conda create -q -n test python=$env:PYTHON_VERSION
activate test

# Set environment variables for environment (activate test doesn't seem to do the trick)
$env:PATH = "C:\conda\envs\test;C:\conda\envs\test\Scripts;C:\conda\envs\test\Library\bin;" + $env:PATH

# Check that we have the expected version of Python
python --version

# Install the specified versions of numpy and other dependencies
if ($env:CONDA_DEPENDENCIES) {
   conda install -n test -q pytest numpy=$env:NUMPY_VERSION $env:CONDA_DEPENDENCIES.Split(" ")
} else {
   conda install -n test -q pytest numpy=$env:NUMPY_VERSION
}

# Check whether astropy is required and if yes install it
if ($env:ASTROPY_VERSION -match "dev") {
   # Install pip and Astropy core build dependencies first
   conda install -n test -q numpy=$env:NUMPY_VERSION Cython jinja2 pip
   pip install git+http://github.com/astropy/astropy.git#egg=astropy
} elseif ($env:ASTROPY_VERSION -match "stable") {
   conda install -n test -q numpy=$env:NUMPY_VERSION astropy
} elseif ($env:ASTROPY_VERSION) {
   conda install -n test -q numpy=$env:NUMPY_VERSION astropy=$env:ASTROPY_VERSION
}