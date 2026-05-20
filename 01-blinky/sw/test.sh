#!/bin/bash
# AXI GPIO loopback smoke test.
# Write a 32-bit value to the output channel (offset 0x00) and read it back
# from the input channel (offset 0x08). They should match.

set -e

GPIO_BASE=0xA0000000
OUT_REG=$(printf "0x%X" $((GPIO_BASE + 0x00)))   # data reg, channel 1 (output)
IN_REG=$(printf "0x%X"  $((GPIO_BASE + 0x08)))   # data reg, channel 2 (input)

VAL=${1:-0xDEADBEEF}

# devmem on Ubuntu lives inside busybox (apt install busybox-static)
DEVMEM="sudo busybox devmem"

echo "Writing $VAL to $OUT_REG"
$DEVMEM $OUT_REG 32 $VAL

READ=$($DEVMEM $IN_REG 32)
echo "Read    $READ from $IN_REG"

if [ "$READ" = "$VAL" ]; then
    echo "PASS: loopback matches"
else
    echo "FAIL: expected $VAL, got $READ"
    exit 1
fi
