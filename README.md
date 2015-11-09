About
=====

This repository contains a set of scripts that are used by the 
``.travis.yml`` and ``appveyor.yml`` files of astropy packages for the 
[Travis](http://travis-ci.org) and [AppVeyor](http://www.appveyor.com/) 
services respectively.

The scripts include:

* ``appveyor/install-miniconda.ps1`` - set up conda on Windows
* ``appveyor/windows_sdk.cmd`` - set up the compiler environment on Windows
* ``travis/setup_dependencies_common.sh`` - set up conda packages on Linux and MacOS X
* ``travis/setup_conda_linux.sh`` - set up conda on Linux
* ``travis/setup_conda_osx.sh`` - set up conda on MacOS X

This repository can be cloned directly from the ``.travis.yml`` and
``appveyor.yml`` files when about to run tests and does not need to be
included as a sub-module in repositories.
