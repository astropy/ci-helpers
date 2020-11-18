## Important notices

This package is no longer actively developed. Please read on below for service-specific
information.

### Travis CI

Astropy Project has decided to move away from Travis CI after they dropped support
for OSS by removing their free-tier plan. Please see
[this announcement](https://groups.google.com/g/astropy-dev/c/45frnTEAX-U)
for more information. We recommend switching to GitHub Actions instead;
you can see an example of it on [astropy](https://github.com/astropy/astropy)
and on [package template](https://github.com/astropy/package-template).

### Appveyor

Scripts for ``appveyor.yml`` for the [AppVeyor](https://www.appveyor.com/)
service are no longer supported. Please use the
[Windows build on Travis](https://docs.travis-ci.com/user/reference/windows/)
instead.

For the usage of the deprecated scripts see [Appveyor scripts README](https://github.com/astropy/ci-helpers/blob/master/appveyor/README.md).

## About

This repository contains a set of scripts that are used by the
``.travis.yml`` file of Astropy packages for the
[Travis](https://travis-ci.com) service.

The idea is to clone these at the last minute when the continuous
integration is about to be run. This is better than including this
repository as a Git sub-module, because this allows updates to this repository
to take effect immediately, and not have to update the Git sub-module every time
a change is made.

## How to use

### Travis (with conda)

*Note that you can also set up Python without conda using ci-helpers - see [here](#setting-up-python-without-conda-on-travis) for more details*

Include the following lines at the start of the ``install`` section in
``.travis.yml``:

```yaml
install:
    - git clone --depth 1 git://github.com/astropy/ci-helpers.git
    - source ci-helpers/travis/setup_conda.sh
```

This does the following:

- Set up Miniconda.
- Set up the PATH appropriately.
- Set up a conda environment named 'test' and switch to it.
- Set the ``always_yes`` config option for conda to ``true`` so that you don't
  need to include ``--yes``.
- Register the specified channels.
- ``export PYTHONIOENCODING=UTF8``
- Supports custom skip tags included in the commit message that are not yet
  natively provided by Travis.
  To run only the docs build: ``[build docs]`` or
  ``[docs only]``. The latter requires ``SETUP_CMD`` (see below) to be set to
  ``build_docs`` or ``build_sphinx``.

Following this, various dependencies are installed depending on the following
environment variables

* ``MAIN_CMD``: if this starts with ``pycodestyle``, ``flake``, or
  ``pylint`` then the only package that gets installed is the
  ``pycodestyle``, ``flake``, or ``pylint`` package. Please note that the
  former name of the ``pycodestyle`` package is ``pep8``, and ci-helpers
  still accepts it, too.

* ``SETUP_CMD``: this can be set to various values:

    * ``egg_info``: no dependencies are installed once the conda environment
      has been created and any other environment variables are ignored.

    * ``build_docs`` or ``build_sphinx``: the Sphinx and matplotlib packages
      are installed in addition to other packages that might be requested
      via other environment variables.

    * ``test``: runs the test suite after the dependencies are installed.

  In addition, if ``SETUP_CMD`` contains the following flags, extra dependencies
  are installed:

    * ``--coverage``: the coverage, coveralls, and codecov packages are installed
    * ``-cov``: the pytest-cov, coveralls, and codecov packages are installed
    * ``--parallel`` or ``--numprocesses``: the pytest-xdist package is
      installed
    * ``--open-files``: the psutil package is installed

* ``MAMBA``: if set to ``True``, conda packages
  will be installed with `mamba <https://github.com/mamba-org/mamba>`_, which is
  both faster than conda and gives more readable errors in cases where there are
  conflicts.

* ``NUMPY_VERSION``: if set to ``dev`` or ``development``, the latest
  developer version of Numpy is installed along with Cython. If set to a
  version number, that version is installed. If set to ``stable``, install
  the latest stable version of Numpy. If set to ``prerelease``, the
  pre-release version of Numpy gets installed if there is any, otherwise the
  build exits and passes on Travis without running the tests. We try to
  avoid downloading and installing mkl, so unless ``mkl`` is specified as a
  dependency in ``CONDA_DEPENDENCIES``, ``nomkl`` is used. On Windows the
  is only MKL, so while the ``nomkl`` package exists it does nothing,
  ``mkl`` is always needed to be installed.

* ``ASTROPY_VERSION``: if set to ``dev`` or ``development``, the latest
  developer version of Astropy is installed, along with Cython and jinja2,
  which are compile-time dependencies. If set to a version number, that
  version is installed. If set to ``stable``, install the latest stable
  version of Astropy. If set to ``prerelease``, the pre-release version of
  Astropy gets installed if there is any, otherwise the build exits and
  passes on Travis without running the tests. If set to ``lts`` the latest
  long term support (LTS) version is installed (more info about LTS can be
  found
  [here](https://github.com/astropy/astropy-APEs/blob/master/APE2.rst#version-numbering).

* ``SUNPY_VERSION``: if set to ``dev`` or ``development``, the latest
  developer version of Sunpy is installed. If set to a
  version number, that version is installed. If set to ``stable``, install
  the latest stable version of Sunpy. If set to ``prerelease``, the
  pre-release version of Sunpy gets installed if there is any, otherwise the
  build exits and passes on Travis without running the tests.

* ``MINICONDA_VERSION``: This sets the version of Miniconda that will be
  installed.  Use this to override a pinned version if necessary.

* ``CONDA_DEPENDENCIES``: this should be a space-separated string of
  package names that will be installed with conda. Version numbers of these
  dependencies can be overridden/specified with the ``PACKAGENAME_VERSION``
  environment variables.

* ``PIP_DEPENDENCIES``: this should be a space-separated string of package
  names that will be installed with pip.

* ``CONDA_DEPENDENCIES_FLAGS``: additional flags to pass to conda when
  installing ``CONDA_DEPENDENCIES``

* ``PIP_DEPENDENCIES_FLAGS``: additional flags to pass to pip when
  installing ``PIP_DEPENDENCIES``

* ``CONDA_CHANNELS``: this should be a space-separated string of conda
  channel names. We don't add any channel by default.

* ``CONDA_ENVIRONMENT``: this is a path to a file that should be used with
  ``conda env create -f $CONDA_ENVIRONMENT``. This is applied to set up the
  test environment *before* the conda and pip dependencies (which otherwise
  act additively with this option).

* ``DEBUG``: if `True` this turns on the shell debug mode in the install
  scripts, and provides information on the current conda install and
  switches off the ``-q`` conda flag for verbose output.

* ``SETUP_XVFB``: if True this makes sure e.g., interactive matplotlib
  backends work by starting up a X virtual framebuffer.

* ``MPLBACKEND``: If not specified it is set to ``Agg`` as the default backend.

* ``PACKAGENAME_VERSION``: ``PACKAGENAME`` is the name of the package to
  specify the version for (e.g. ``MATPLOTLIB_VERSION``). Due to shell
  limitations, all hyphens in the conda package name should be changed to
  underscores in ``PACKAGENAME_VERSION`` (e.g. for scikit-image it should
  be ``SCIKIT_IMAGE_VERSION``). If specified it will override any version
  number limitations listed in ``CONDA_DEPENDENCIES``.

* ``CONDA_CHANNEL_PRIORITY``: can be set to ``strict``, ``flexible`` or ``disabled``, and
  affects the ``channel_priority`` conda setting (as discussed
  [here](https://docs.conda.io/projects/conda/en/latest/user-guide/tasks/manage-channels.html). The default is
  ``disabled``.

* ``EVENT_TYPE``: this should be a space-separated string of event
  types. If given, the build will run only if the ``TRAVIS_EVENT_TYPE``
  matches with any of the listed ones. Otherwise the build exits and passes
  on Travis without running the tests. This is a way to control builds to
  run only on pushes to master, or for Travis cron jobs. Valid event types
  are: ``push``, ``pull_request``, ``api`` or ``cron``.

* ``PIP_FALLBACK``: the default behaviour is to fall back to try to pip
  install a package if installing it with conda fails for any reason. Set
  this variable to ``false`` to opt out of this.

* ``RETRY_ERRORS``: a space-separated string of error names. If not set, this
  will default to ``RETRY_ERRORS="CondaHTTPError"``. When package installation
  via conda fails, the respective command's output (stdout and stderr) is
  searched for the strings in ``RETRY_ERRORS``. If any of these is found, the
  installation will be automatically retried.

* ``RETRY_MAX``: an integer specifying the maximum number of automatic retries.
  If not set, this will default to ``RETRY_MAX=3``. Setting ``RETRY_MAX`` to
  zero will disable automatic retries.

* ``RETRY_DELAY``: a positive integer specifying the number of seconds to wait
  before retrying. If not set, this will default to ``RETRY_DELAY=2``.

* ``MACOSX_DEPLOYMENT_TARGET`` (OSX only): If left blank, the minimum OSX target
  version for LLVM/Clang builds will be set to ``10.9``.
  If set to ``"clang_default"``, determining the minimum OSX target version is
  left to LLVM/Clang. If set to any different value, that value will be used.

The idea behind the ``MAIN_CMD`` and ``SETUP_CMD`` environment variables is
that the ``script`` section of the ``.travis.yml`` file can be set to:

```
script:
    - $MAIN_CMD $SETUP_CMD
```

The typical usage will then be to set ``MAIN_CMD`` to default to ``python
setup.py`` and then set ``SETUP_CMD='test'``, and this then allows special
builds that have ``MAIN_CMD='pycodestyle'`` and ``SETUP_CMD=''``.

Packages can also choose to not use the ``MAIN_CMD`` variable and instead
to set the ``script`` section to:

```
script:
    - python setup.py $SETUP_CMD
```

and simply adjust ``SETUP_CMD`` as needed.

Following the set-up, if additional packages need to be installed, the
``CONDA_INSTALL`` environment variable should be used to make sure that the
Python and Numpy versions stay fixed to those requested, e.g.

```
- $CONDA_INSTALL another_package
```

### Setting up Python without conda on Travis

We also provide a script to set up Python on MacOS X and Windows without making
use of conda. To use this include the following lines at the start of the
``install`` section in ``.travis.yml``:

```yaml
install:
    - git clone --depth 1 git://github.com/astropy/ci-helpers.git
    - source ci-helpers/travis/setup_python.sh
```

You will need to set the ``PYTHON_VERSION`` environment variable to the
major.minor version of Python that you want to have installed (e.g. 3.8)

The script does nothing on Linux, so it is safe to call as above without special
casing the operating system. On Linux, you should instead use ``language:
python`` provide the Python version with ``python: ...``.

The script also sets up a virtual environment using
[venv](https://docs.python.org/3/library/venv.html) and upgrades pip to the
latest version, but does not install any other packages. This is deliberate as we want to keep this script as minimal as possible.

### pip pinnings

We also provide a file called
[pip_pinnings.txt](https://github.com/astropy/ci-helpers/blob/master/pip_pinnings.rst)
which contains any version pins we currently recommend. This file is in the
[pip requirements](https://pip.pypa.io/en/stable/user_guide/#requirements-files) format.
Often this file will be empty if no pinnings are recommended. This file is suitable for
use with any tools that understand pip requirements files, including for example
[tox-pypi-filter](https://pypi.org/project/tox-pypi-filter/).

### Utils

A directory to collect all kinds of useful scripts to be used during various
CI runs.

* ``import_submodules.py`` - utility script to make it possible to test
  importing submodules when optional dependencies, including pytest, are
  missing.

## Details

The scripts include:

* ``travis/setup_dependencies_common.sh`` - set up conda packages on Linux and
  MacOS X
* ``travis/setup_conda.sh`` - set up conda on MacOS X or Linux, users should use
  this directly rather than the OS specific ones below
* ``travis/setup_conda_linux.sh`` - set up conda on Linux
* ``travis/setup_conda_osx.sh`` - set up conda on MacOS X
* ``travis/setup_python.sh`` - set up Python on MacOS X and Windows without conda

This repository can be cloned directly from the ``.travis.yml``
file when about to run tests and does not need to be included
as a Git sub-module in repositories.
