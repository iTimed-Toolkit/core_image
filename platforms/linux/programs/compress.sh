#!/bin/bash

cat $1 | gzip | base64 -w0
