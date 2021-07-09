#!/bin/bash

PATCHES=$(cd "$PROJECT_ROOT/patches" ; find . -name *.patch)
for patch in $PATCHES
do
    ppath=$(dirname "$patch")
    pname=$(basename "$patch")

    # paths correspond to the containing directory of patches/
    if [[ -d "$PROJECT_ROOT/$ppath" ]]
    then
        cd "$PROJECT_ROOT/$ppath"
        if ! git apply "$PROJECT_ROOT/patches/$patch"
        then
            echo "Failed to apply patch $pname"
            exit -1
        fi
        cd "$PROJECT_ROOT"
    else
        echo "Invalid patch directory $ppath"
        exit -1
    fi
done
