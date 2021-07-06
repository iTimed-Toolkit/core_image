#!/bin/bash
source "$ENVFILE"

# Resolve all image symlinks
for f in $PLATFORM_ROOT/images/*
do
    if [[ -L "$f" ]]
    then
        cp --remove-destination $(readlink -f "$f") "$f"
    fi
done

# Also copy host-side toolchain files
sudo cp $SANDCASTLE_BUILD_ROOT/output/host/* /usr/local/

