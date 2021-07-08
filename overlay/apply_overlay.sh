#!/bin/bash

currdir=$(pwd)
FILES=$(find . -type f)

for f in $FILES
do
    # skip copying this script
    if [[ "$f" == "./apply_overlay.sh" ]]
    then
        continue
    fi

    fpath=$(dirname "$f")
    fname=$(basename "$f")

    # paths correspond to the containing directory of overlay/
    mkdir -p "../$fpath"
    if ! cp "$f" "../$fpath/"
    then
        echo "Failed to overlay $fname"
        exit -1
    fi
done
