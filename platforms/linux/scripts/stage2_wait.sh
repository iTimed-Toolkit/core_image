#!/bin/bash

if [[ $# != 1 ]]; then
    echo "usage: ./stage2_wait.sh [timeout]"
    exit 1
fi

START=$(date -u +%s)
while true; do
    PONGO_EXISTS=$(lsusb -d 05ac:4141)
    if [[ "$PONGO_EXISTS" != "" ]]; then
        exit 0
    fi

    sleep 1s

    NOW=$(date -u +%s)
    ELAPSED=$(($NOW - $START))

    if (( "$ELAPSED" >= "$1" )); then
        # timed out
        echo "error: timed out"
        exit 1
    fi
done
