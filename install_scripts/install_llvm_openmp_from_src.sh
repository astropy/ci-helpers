#!/bin/bash

# Script to build and install llvm-openmp from SVN trunk

set -ev

svn co http://llvm.org/svn/llvm-project/openmp/trunk openmp
mkdir openmp-build && cd openmp-build
cmake ../openmp
make
make install
cd ../

set +ev
