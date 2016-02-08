#!/bin/bash

# Default to using conda unless otherwise specified
if [[ -z $USE_CONDA ]]; then
    USE_CONDA=True;
fi

if [[ $USE_CONDA == True ]]; then
  source ci-helpers/travis/setup_conda_$TRAVIS_OS_NAME.sh;
else
  if [[ $TRAVIS_OS_NAME != osx ]]; then
    echo "Non-conda testing is only available on MacOS X at this time";
    exit 100;
  fi
  if [[ $ARCH != i386 ]]; then
    echo "When not using conda, only 32-bit testing is available at this time";
    exit 100;
  fi
  source "ci-helpers/travis/setup_python_"$ARCH".sh";
fi
  