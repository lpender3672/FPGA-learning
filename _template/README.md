# NN-name

One-line description.

## What's in the PL

(Block-design summary.)

## Register map

| Offset | Reg | Direction | Notes |
|---|---|---|---|
| 0x00 | ... | RW | ... |

## Build & run

```powershell
..\scripts\deploy.ps1 -Project NN-name
ssh kv260 ./test.sh
```

## Simulate

```powershell
..\scripts\sim.ps1 -Project NN-name
```

The template ships with `hw/src/example_counter.sv` + `sim/tb.py` as a
working cocotb-against-xsim smoke test. Replace the DUT and test when
you write real RTL. Update `HDL_TOPLEVEL` in `sim/runner.py` to match
your top module name.
