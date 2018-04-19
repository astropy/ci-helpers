#!/bin/bash

# Script to brew install LLVM's clang

set -ev

brew install llvm --with-clang
export PATH="/usr/local/opt/llvm/bin:$PATH"
export C_INCLUDE_PATH="/usr/local/opt/llvm/include:$C_INCLUDE_PATH"
export LD_LIBRARY_PATH="/usr/local/opt/llvm/lib:$LD_LIBRARY_PATH"
export LDFLAGS=$LDFLAGS" -L/usr/local/opt/llvm/lib -Wl,-rpath,/usr/local/opt/llvm/lib"
export CC="/usr/local/opt/llvm/bin/clang"

set +ev
