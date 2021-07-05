#!/bin/bash

if [[ $# != 1 ]]; then
    echo "usage: ./stage1_checkra1n.sh [pongo image]"
    exit 1
fi

# check if DFU mode

DFU_EXISTS=$(lsusb -d 05ac:1227)
if [[ "$DFU_EXISTS" != "" ]]; then
    checkra1n -c -k $1 -p -E
#    sudo checkra1n -c -p -E
    exit 0
fi

# if no DFU mode, pongo should exist

PONGO_EXISTS=$(lsusb -d 05ac:4141)
if [[ "$PONGO_EXISTS" == "" ]]; then
    # no pongo or DFU
    echo "error: no DFU or pongo modes detected"
    exit 1
else
    # we're in pongo, skip this stage
    exit 0
fi
