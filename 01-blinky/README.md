# 01-blinky

AXI GPIO loopback. The simplest end-to-end exercise that proves the
full toolchain works: RTL -> Vivado bitstream -> bootgen -> scp ->
xmutil loadapp -> device-tree binding -> devmem register round-trip.

## What's in the PL

A Zynq UltraScale+ Processing System with one dual-channel AXI GPIO IP
at `0xA000_0000`. Channel 1 is 32 bits output; channel 2 is 32 bits
input. The two channels are wired together internally so a write to
channel 1 reads back on channel 2.

No physical pins are used, so the design works on any KV260 without
extra hardware.

## Register map

| Offset | Reg | Direction | Notes |
|---|---|---|---|
| 0x00 | GPIO_DATA  | RW | channel 1 (loopback driver, output of GPIO IP) |
| 0x08 | GPIO2_DATA | R  | channel 2 (loopback receiver, input of GPIO IP) |

A write to `0xA0000000` should be visible at `0xA0000008` on the next read.

## Build & run

```powershell
..\scripts\deploy.ps1 -Project 01-blinky
ssh kv260 ./test.sh
```

## Simulation

```powershell
..\scripts\sim.ps1 -Project 01-blinky
```

The deployed BD uses Xilinx's AXI GPIO IP directly, so the cocotb
testbench currently runs against a placeholder DUT (`example_counter.sv`)
that's NOT in the synthesised design — it exists only to exercise the
sim flow end-to-end. Replace with real RTL when you add custom logic.

Expected output:
```
Writing 0xDEADBEEF to 0xA0000000
Read    0xDEADBEEF from 0xA0000008
PASS: loopback matches
```

## Why the device-tree overlay matters

The PS's PL clocks are gated off by default on Zynq UltraScale+. Without
the `clocking@0` node (`compatible = "xlnx,fclk"`) in `firmware/pl.dts`,
PL_CLK0 stays off, the AXI fabric has no clock, and a write to the GPIO
hangs the CPU on a never-acknowledged bus transaction. The dtbo here
enables PL_CLK0 and feeds it into the GPIO node via a `fixed-clock`
proxy so the driver attaches cleanly.
