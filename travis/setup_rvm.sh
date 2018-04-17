#!/bin/bash

command curl -sSL https://rvm.io/mpapis.asc | gpg --import -;
rvm get stable
