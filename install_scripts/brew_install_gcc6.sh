#!/bin/bash

# Script to brew install GCC 6.0

set -ev

# remove existing c++ to prevent brew from failing
rm /usr/local/include/c++

brew install gcc6
export CC=gcc-6
export CXX=g++-6;
export CFLAGS="-m64"
export LDFLAGS="-m64"

set +ev
