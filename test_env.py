import os
import sys

# The test scripts accept 'stable' for ASTROPY_VERSION to test that it's
# properly parsed hard-wire the latest stable branch version here

LATEST_ASTROPY_STABLE = '1.1'
LATEST_ASTROPY_LTS = '1.0'
LATEST_NUMPY_STABLE = '1.10'

if os.environ.get('PIP_DEPENDENCIES', None) is not None:
    PIP_DEPENDENCIES = os.environ['PIP_DEPENDENCIES'].split(' ')
else:
    PIP_DEPENDENCIES = []

if os.environ.get('CONDA_DEPENDENCIES', None) is not None:
    CONDA_DEPENDENCIES = os.environ['CONDA_DEPENDENCIES'].split(' ')
else:
    CONDA_DEPENDENCIES = []

dependency_list = PIP_DEPENDENCIES + CONDA_DEPENDENCIES


def test_python_version():
    if 'PYTHON_VERSION' in os.environ:
        assert sys.version.startswith(os.environ['PYTHON_VERSION'])
    elif 'TRAVIS_PYTHON_VERSION' in os.environ:
        assert sys.version.startswith(os.environ['TRAVIS_PYTHON_VERSION'])


def test_numpy():
    if 'NUMPY_VERSION' in os.environ:
        import numpy
        if 'dev' in os.environ['NUMPY_VERSION']:
            assert 'dev' in numpy.__version__
        else:
            if 'stable' in os.environ['NUMPY_VERSION']:
                assert numpy.__version__.startswith(LATEST_NUMPY_STABLE)
            else:
                assert numpy.__version__.startswith(os.environ['NUMPY_VERSION'])
            assert 'dev' not in numpy.__version__


def test_astropy():
    if 'ASTROPY_VERSION' in os.environ:
        import astropy
        if 'dev' in os.environ['ASTROPY_VERSION']:
            assert 'dev' in astropy.__version__
        else:
            if 'stable' in os.environ['ASTROPY_VERSION']:
                assert astropy.__version__.startswith(LATEST_ASTROPY_STABLE)
            elif 'lts' in os.environ['ASTROPY_VERSION']:
                assert astropy.__version__.startswith(LATEST_ASTROPY_LTS)
            else:
                assert astropy.__version__.startswith(os.environ['ASTROPY_VERSION'])
            assert 'dev' not in astropy.__version__


# Check whether everything is installed and importable
def test_dependency_imports():
    for package in dependency_list:
        __import__(package)


def test_sphinx():
    if 'SETUP_CMD' in os.environ:
        if ('build_sphinx' in os.environ['SETUP_CMD'] or
            'build_docs' in os.environ['SETUP_CMD']):
            import sphinx


def test_open_files():
    if 'open-files' in os.environ.get('SETUP_CMD', ''):
        import psutil
