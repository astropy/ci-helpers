About
-----

[![Build Status](https://travis-ci.org/astrofrog/ci-helpers.svg?branch=master)](https://travis-ci.org/astrofrog/ci-helpers)
[![Build status](https://ci.appveyor.com/api/projects/status/4mqtucv6ks4peakf/branch/master?svg=true)](https://ci.appveyor.com/project/Astropy/ci-helpers/branch/master)

This repository contains a set of scripts that are used by the 
``.travis.yml`` and ``appveyor.yml`` files of astropy packages for the 
[Travis](http://travis-ci.org) and [AppVeyor](http://www.appveyor.com/) 
services respectively.

How to use
----------

### Travis

Include the following lines at the start of the ``before_install`` section in ``.travis.yml``:

```
before_install:
    - git clone git://github.com/astropy/ci-helpers.git
    - source ci-helpers/travis/setup_environment_$TRAVIS_OS_NAME.sh
```

### AppVeyor

Include the following lines at the start of the ``install`` section in ``appveyor.yml``:

```
install:
    - "git clone git://github.com/astropy/ci-helpers.git"
    - "powershell ci-helpers/appveyor/install-miniconda.ps1"
    - "SET PATH=%PYTHON%;%PYTHON%\\Scripts;%PATH%"
```

What this does
--------------

The above lines:

- Set up Miniconda
- Set up the PATH appropriately
- Set up a conda environment named 'test' and switch to it
- Set the ``always_yes`` config option for conda to ``true`` so that you don't need to include ``--yes``
- Install dependencies based on environment variables (instructions will be added here soon)

Details
-------

The scripts include:

* ``appveyor/install-miniconda.ps1`` - set up conda on Windows
* ``appveyor/windows_sdk.cmd`` - set up the compiler environment on Windows
* ``travis/setup_dependencies_common.sh`` - set up conda packages on Linux and MacOS X
* ``travis/setup_conda_linux.sh`` - set up conda on Linux
* ``travis/setup_conda_osx.sh`` - set up conda on MacOS X

This repository can be cloned directly from the ``.travis.yml`` and
``appveyor.yml`` files when about to run tests and does not need to be
included as a sub-module in repositories.
