#!/bin/bash

for f in ./linux/images/*
do
    cp --remove-destination $(readlink -f "$f") "$f"
done
