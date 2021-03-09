About
-----

Appveyor is no longer supported. The scripts are provided as-is.
They will be removed at some point in the future.

### AppVeyor

Include the following lines at the start of the ``install`` section in
``appveyor.yml``:

```yaml
install:
    - "git clone --depth 1 git://github.com/astropy/ci-helpers.git"
    - "powershell ci-helpers/appveyor/install-miniconda.ps1"
    - "conda activate test"
```

This does the following:

- Set up Miniconda.
- Set up the PATH appropriately.
- Set up a conda environment named 'test' and switch to it.
- Set the ``always_yes`` config option for conda to ``true`` so that you don't
  need to include ``--yes``.

Following this, various dependencies are installed depending on the following
environment variables:

* ``NUMPY_VERSION``: if set to ``dev`` or ``development``, the latest
  developer version of Numpy is installed along with Cython. If set to a
  version number, that version is installed.  If set to ``stable``, install
  the latest stable version of Numpy.

* ``ASTROPY_VERSION``: if set to ``dev`` or ``development``, the latest
  developer version of Astropy is installed, along with Cython and jinja2,
  which are compile-time dependencies. If set to a version number, that
  version is installed. If set to ``stable``, install the latest stable
  version of Astropy. If set to ``lts`` the latest long term support (LTS)
  version is installed (more info about LTS can be found
  [here](https://github.com/astropy/astropy-APEs/blob/main/APE2.rst#version-numbering)).

* ``SUNPY_VERSION``: if set to ``dev`` or ``development``, the latest
  developer version of Sunpy is installed. If set to a
  version number, that version is installed. If set to ``stable``, install
  the latest stable version of Sunpy.

* ``MINICONDA_VERSION``: this sets the version of Miniconda that will be
  installed.  Use this to override a pinned version if necessary.

* ``CONDA_DEPENDENCIES``: this should be a space-separated string of package
  names that will be installed with conda.

* ``CONDA_CHANNELS``: this should be a space-separated string of conda
  channel names. We don't add any channel by default.

* ``DEBUG``: if `True` this turns on the shell debug mode in the install
  scripts, and provides information on the current conda install and
  switches off the ``-q`` conda flag for verbose output.

* ``PIP_FALLBACK``: the default behaviour is to fall back to try to pip
  install a package if installing it with conda fails for any reason. Set
  this variable to ``false`` to opt out of this.

* ``RETRY_ERRORS``: a comma-separated string array containing error names.
  If not set, this will default to ``$RETRY_ERRORS="CondaHTTPError"``. When
  package installation via conda fails, the respective command's error output
  (stderr) is searched for the strings in ``RETRY_ERRORS``. If any of these is
  found, the installation will be automatically retried. Setting
  ``RETRY_ERRORS`` in ``appveyor.yml`` will *overwrite* the default.

* ``RETRY_MAX``: an integer specifying the maximum number of automatic retries.
  If not set, this will default to ``$RETRY_MAX=3``. Setting ``RETRY_MAX`` to
  zero will disable automatic retries.

* ``RETRY_DELAY``: a positive integer specifying the number of seconds to wait
  before retrying. If not set, this will default to ``$RETRY_DELAY=2``.

Details
-------

The scripts include:

* ``appveyor/install-miniconda.ps1`` - set up conda on Windows
* ``appveyor/windows_sdk.cmd`` - set up the compiler environment on Windows
