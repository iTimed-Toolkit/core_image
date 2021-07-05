#!/bin/bash

currdir=$(pwd)
PATCHES=$(find -name *.patch)

for patch in $PATCHES
do
    ppath=$(dirname "$patch")
    pname=$(basename "$patch")

    # paths correspond to the containing directory of patches/
    if [[ -d "../$ppath" ]]
    then
        cd "../$ppath"
        if ! git apply "$currdir/$patch"
        then
            echo "Failed to apply patch $pname"
            exit -1
        fi
        cd "$currdir"
    else
        echo "Invalid patch directory $ppath"
        exit -1
    fi
done
