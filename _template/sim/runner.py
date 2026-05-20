"""Driver for the cocotb simulation. Run via `scripts\\sim.ps1 -Project <dir>`.

Convention:
  - RTL sources are auto-discovered from hw/src/*.{sv,v}
  - The cocotb test module is sim/tb.py
  - hdl_toplevel below MUST match the SystemVerilog module name being tested
"""
import sys
from pathlib import Path

from cocotb_tools.runner import get_runner, get_results

PROJECT_DIR = Path(__file__).resolve().parent.parent
SRC_DIR     = PROJECT_DIR / "hw" / "src"
SIM_DIR     = PROJECT_DIR / "sim"
BUILD_DIR   = PROJECT_DIR / "build" / "sim"

HDL_TOPLEVEL = "example_counter"

def main():
    sources = sorted(SRC_DIR.glob("*.sv")) + sorted(SRC_DIR.glob("*.v"))
    if not sources:
        raise SystemExit(f"No RTL sources under {SRC_DIR}")

    runner = get_runner("verilator")
    runner.build(
        sources=sources,
        hdl_toplevel=HDL_TOPLEVEL,
        build_dir=str(BUILD_DIR),
        always=True,
        waves=True,
    )
    results_xml = runner.test(
        hdl_toplevel=HDL_TOPLEVEL,
        test_module="tb",
        build_dir=str(BUILD_DIR),
        test_dir=str(SIM_DIR),
        waves=True,
    )

    num_tests, num_failed = get_results(results_xml)
    if num_failed:
        sys.exit(f"{num_failed} of {num_tests} test(s) failed")

if __name__ == "__main__":
    main()
