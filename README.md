# FPGA-learning

KV260 (Zynq UltraScale+ MPSoC) projects, structured for fast iteration.
All projects share one deploy pipeline and target the same board.

## Layout

```
scripts/deploy.ps1     parameterised deploy: -Project <dir>
_template/             skeleton to copy when starting a new project
01-blinky/             AXI GPIO loopback, end-to-end first project
NN-<name>/             further projects, numbered by learning order
```

Each project subdir is self-contained:
- `hw/` Vivado-side sources (build.tcl, BD Tcl, RTL, constraints)
- `firmware/` artifacts that ship to the board (pl.dts, shell.json, design.bif)
- `sw/` on-board scripts (mostly test.sh)
- `build/` (gitignored) Vivado outputs, ~1-5 GB per project

## Workflow

From a plain PowerShell (no need for the Vivado command prompt):

```powershell
.\scripts\deploy.ps1 -Project 01-blinky               # full build + deploy
.\scripts\deploy.ps1 -Project 01-blinky -SkipBuild    # iterate when only DT/shell changed
ssh kv260 ./test.sh                                    # run the on-board smoke test
```

Or use the VSCode tasks (Ctrl+Shift+P -> "Tasks: Run Task").

## Prerequisites

- **Windows PC**: Vivado + Vitis 2025.2 under `C:\AMDDesignTools\2025.2\`
  (pass `-XilinxRoot` to override). The script sources `settings64.bat` itself.
- **KV260**: Ubuntu 24.04 with `xmutil`, `xrt`, `busybox-static`, `device-tree-compiler`
  installed. Passwordless sudo for the deploy user.
- **SSH**: alias `kv260` in `~/.ssh/config`.

## Starting a new project

```powershell
Copy-Item _template 02-counter -Recurse
# edit 02-counter/hw/bd/design_1.tcl, 02-counter/firmware/pl.dts, etc.
.\scripts\deploy.ps1 -Project 02-counter
```

The app name on the board matches the project directory name, so each
project occupies its own `/lib/firmware/xilinx/<name>/` slot and they
don't collide.

## Projects

| Dir | What it does | Address |
|---|---|---|
| 01-blinky | AXI GPIO loopback. Write a 32-bit value, read it back. | 0xA000_0000 |
