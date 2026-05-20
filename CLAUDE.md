# Notes for Claude

Operational context for this repo. Pairs with `README.md` (human intro).

## Topology

Three machines:
- **Windows host** — editor, Vivado/bootgen, `scripts/deploy.ps1`.
- **WSL2 Ubuntu-24.04** — Verilator + cocotb. `scripts/sim.ps1` shells out via `wsl.exe`.
- **KV260** — Ubuntu 24.04 with `xmutil`. Reached as `ubuntu@kria.tailb8a52e.ts.net` (default in scripts).

## Verify before reporting done

Match the verifier to what you changed. Never report "should work":

| Changed                              | Verify                                                     |
|--------------------------------------|------------------------------------------------------------|
| `<p>/hw/src/*.{sv,v}`                | `.\scripts\sim.ps1 -Project <p>`                           |
| `<p>/firmware/pl.dts` only           | `.\scripts\deploy.ps1 -Project <p> -SkipBuild` + `test.sh` |
| `<p>/hw/bd/*.tcl` or constraints     | `.\scripts\deploy.ps1 -Project <p>` (full build)           |
| `scripts/*.ps1`                      | `Get-Command -Syntax ...` then a real run                  |

Diagnose unfamiliar failures first: `.\scripts\diagnose.ps1` prints a structured snapshot of all three machines. Cheaper than guessing layers.

## Ask when faster than inferring

Hardware ground truth beats speculation. If diagnosis needs something the user can see, feel, or probe — ask. 10 s of their attention beats 10 min of my context burn on guessing chains.

Worth asking instead of guessing:
- "Is the board's power/done LED actually on?"
- "Drop an ILA on signal `<name>` and tell me when it toggles."
- "Set a breakpoint in Vitis at `<addr>` — what's the value?"
- "Wiggle the USB-JTAG cable. Does the link drop?"
- "Power-cycle and re-run — does the failure repro?"

Self-drive in software-land (RTL, deploy, sim, ssh-reachable state). Hand back when the answer lives on the bench.

## Result markers

`deploy.ps1`, `sim.ps1`, `sim.sh` all end with one parseable line:

```
[result] deploy ok
[result] deploy fail: <reason>
[result] sim ok
[result] sim fail: <reason>
```

Grep the last line. Read full log only on `fail`.

## Gotchas

Each was multi-hour from cold. Recognise symptom, skip rediscovery.

- **Unmapped AXI write → board hangs.** Writing to a base address with no responding slave (wrong addr, gated clock, asserted reset) stalls the ARM forever. Always check `cat /sys/class/fpga_manager/fpga0/state` (expect `operating`), `ls /sys/bus/platform/devices/ | grep -i gpio` (expect device node), and `dmesg | tail` *before* poking registers.

- **PL clocks are gated by default.** The dtbo must contain a `clocking@0` node with `compatible = "xlnx,fclk"` referencing `&zynqmp_clk 71` (= PL0_REF). See `01-blinky/firmware/pl.dts`.

- **IP version drift.** Each `bd/design_1.tcl` ends with a lockfile check that errors if Vivado swapped an IP rev. Update the dict deliberately after re-testing — do not auto-bump.

- **cocotb NBA timing.** After `await RisingEdge(clk)`, NBAs haven't committed. Always `await ReadOnly()` (or `FallingEdge`) before reading signals — see `01-blinky/sim/tb.py`.

- **Address map duplicated.** Base address lives in *two* places: `bd/design_1.tcl` (`assign_bd_address -offset ...`) and `firmware/pl.dts` (`reg = <...>`). `deploy.ps1` only auto-syncs `firmware-name`, not the address. Change one → change the other.

- **Cocotb 2.x needs Verilator ≥ 5.022.** Ubuntu 24.04 apt ships 5.020. `setup-sim.sh` builds `v5.026` from source into `.verilator-build/` when needed.

## Conventions

- App names on the board = project directory name verbatim. Stick to `[a-z0-9-]`.
- `HDL_TOPLEVEL` in `sim/runner.py` must equal the SystemVerilog module name being tested.
- RTL in `hw/src/*.sv` is both synthesised (if reachable from BD top) and auto-discovered by the sim runner. Sim-only modules produce a benign "unused" Vivado warning.
- IP-version lockfile (end of `hw/bd/design_1.tcl`) is updated *after* deliberate review, not before.

## Don't

- **Touch git at all.** No `git add`, `commit`, `branch`, `stash`, `push`, `reset`, `checkout`. Commits, branches, and pushes are the user's call. Edit files; let them stage and commit.
- Run `pio` or PlatformIO/Teensy commands here (different env).
- Mass-delete under `/lib/firmware/xilinx/` or unload apps without checking state first.
- Wipe `.venv` without saying why — 5-min rebuild.
