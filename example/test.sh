#!/bin/bash

DC="${DC:-ldc2}"

set -e

for example in $(dirname ${BASH_SOURCE})/*.d; do
    echo
    echo -e "\e[93mtest $example\e[0m"
    dub --single $example --compiler=${DC}
    echo -e "\e[92m$example success\e[0m"
done
