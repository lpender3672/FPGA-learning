#!/bin/bash
# Smoke test for this project. Adjust to match your address map.
set -e

# devmem lives in busybox on Ubuntu (apt install busybox-static).
DEVMEM="sudo busybox devmem"

# Example: read a register.
# $DEVMEM 0xA0000000 32

echo "TODO: write a test for this project"
