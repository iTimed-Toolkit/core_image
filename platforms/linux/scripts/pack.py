#!/usr/bin/python3

import os
import sys

if len(sys.argv) != 2:
    print('usage: pack.py [dtb dir]')
    exit(1)

result = b'Cows'

for fname in os.listdir(sys.argv[1]):
    if fname.endswith(".dtb"):
        with open(sys.argv[1] + fname, "rb") as f:
            data = f.read()

        name = fname.split(".")[0].split("-")[2].upper().encode() + b'\x00'
        result += name
        result += len(data).to_bytes(4, "big")
        result += data

with open("dtbpack", "wb+") as f:
    f.write(result)
