# FPGA-learning

KV260 (Zynq UltraScale+ MPSoC) projects, structured for a fast feedback
loop. All projects share one deploy pipeline and one sim pipeline, and
target the same board.

## What runs where

```
                Windows host                  WSL2 (Ubuntu-24.04)              KV260
                ------------                  -------------------              -----
  edit + git    Vivado + bootgen              cocotb + Verilator               xmutil
                 |                             |                                |
                 v                             v                                v
                deploy.ps1 -------scp/ssh--> /lib/firmware/xilinx/<app>/
                sim.ps1   ---wsl.exe--> sim.sh (runs the sim)
```

- **Windows**: editor, Vivado, the deploy pipeline.
- **WSL2 (Ubuntu-24.04)**: simulation only. The cocotb runner needs Verilator >= 5.022,
  which Ubuntu 24.04 doesn't ship yet, so `setup-sim.ps1` builds it from source on first run.
- **KV260**: Ubuntu 24.04 with `xmutil`, `xrt`, `busybox-static`, `device-tree-compiler`.
  Loads bitstreams via xmutil + device-tree overlays.

## Layout

```
scripts/
  deploy.ps1        build + scp + xmutil loadapp (Windows)
  sim.ps1           wrapper that invokes sim.sh in WSL
  sim.sh            cocotb-against-verilator runner (WSL)
  setup-sim.ps1     one-time: provisions the WSL sim env
  setup-sim.sh      one-time: builds Verilator + venv (WSL)
_template/          skeleton to copy when starting a new project
01-blinky/          AXI GPIO loopback, the first end-to-end project
NN-<name>/          further projects, numbered by learning order
.vscode/tasks.json  Deploy / Simulate / board diagnostics
```

Each project subdir is self-contained:
- `hw/` Vivado-side sources (`build.tcl`, BD Tcl, RTL under `src/`, constraints)
- `firmware/` artifacts that ship to the board (`pl.dts`, `shell.json`, `design.bif`)
- `sim/` cocotb testbench (`tb.py`) and runner (`runner.py`)
- `sw/` on-board scripts (`test.sh`)
- `build/` (gitignored) Vivado outputs (~1-5 GB) + sim build dir

## Deploy workflow

```powershell
.\scripts\deploy.ps1 -Project 01-blinky               # full Vivado build + ship + xmutil load
.\scripts\deploy.ps1 -Project 01-blinky -SkipBuild    # reuse bitstream, just re-ship DT/firmware
ssh kv260 ./test.sh                                    # on-board smoke test
```

Or use the VSCode tasks (`Ctrl+Shift+P` → "Tasks: Run Task" → "Deploy").

## Simulation workflow

```powershell
.\scripts\sim.ps1 -Project 01-blinky                  # ~5 s per iteration
```

Cocotb 2.x + Verilator inside WSL2. The PowerShell wrapper does the
Windows→Linux path translation and shells out to `wsl.exe`, so the
VSCode "Simulate" task works the same way.

Each project's `sim/runner.py` auto-discovers `hw/src/*.{sv,v}` as
sources. To point at a different top-level module, edit
`HDL_TOPLEVEL` in that file.

## One-time setup

### Windows
- Install **Vivado + Vitis 2025.2** to `C:\AMDDesignTools\2025.2\`
  (or pass `-XilinxRoot` to deploy.ps1). The scripts source
  `settings64.bat` themselves, so a plain PowerShell works.

### WSL (for simulation)
```powershell
wsl --install -d Ubuntu-24.04          # ~5 min, one-time
wsl --set-default Ubuntu-24.04         # so scripts pick it up by default
.\scripts\setup-sim.ps1                # builds Verilator from source + venv + cocotb (~5 min first run)
```

Ubuntu 20.04/22.04 will *not* work — Verilator from apt is too old for cocotb 2.x.

### KV260
- Stock Kria Ubuntu 24.04 image (works out of the box).
- One-time on the board:
  ```bash
  sudo apt-get install -y busybox-static device-tree-compiler
  echo 'ubuntu ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/ubuntu-nopasswd
  sudo chmod 440 /etc/sudoers.d/ubuntu-nopasswd
  ```
  (Tighter than `NOPASSWD: ALL` is sensible on a shared box — scope to
  `xmutil`, `mv`, `rm`, `apt-get`, `dtc`.)

### SSH alias
In `~/.ssh/config` on the Windows side:
```
Host kv260
    HostName <board-ip-or-tailscale-name>
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
```
Then `ssh-copy-id`-equivalent the public key over once and you're done.

## Starting a new project

```powershell
Copy-Item _template 02-counter -Recurse
# Edit 02-counter/hw/bd/design_1.tcl, 02-counter/firmware/pl.dts, etc.
# In sim/runner.py, update HDL_TOPLEVEL to match your DUT module name.
.\scripts\sim.ps1    -Project 02-counter            # iterate on RTL first
.\scripts\deploy.ps1 -Project 02-counter            # then push to hardware
```

The app name on the board matches the project directory name, so each
project occupies its own `/lib/firmware/xilinx/<name>/` slot and they
don't collide. Project names are passed directly into Vivado / DTS /
`xmutil` so stick to `[a-z0-9-]`.

## Projects

| Dir | What it does | Base address |
|---|---|---|
| 01-blinky | AXI GPIO loopback. Write a 32-bit value, read it back. | `0xA000_0000` |

## Gotchas worth remembering

- **Unmapped AXI writes hang the PS hard.** A write to an address with no
  responding slave (wrong base address, clock-gated peripheral, missing
  reset) stalls the ARM core forever — no SSH, no recovery, power-cycle.
  Always verify the dtbo loaded cleanly (`dmesg | tail`, `/sys/bus/platform/devices/`)
  before touching registers.
- **PL clocks are gated off by default.** The dtbo must declare a
  `clocking@0` node with `compatible = "xlnx,fclk"` to enable PL_CLK0,
  or your AXI fabric runs with no clock.
- **IP version drift.** Vivado silently substitutes IP revs across
  versions. Each project's `bd/design_1.tcl` has a version lockfile at
  the end that fails the build if a Vivado upgrade changes anything.
- **Cocotb timing.** After `await RisingEdge(clk)`, NBAs haven't
  committed yet. Always `await ReadOnly()` before reading signals,
  otherwise you'll see stale values.
