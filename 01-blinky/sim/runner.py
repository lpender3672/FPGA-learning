"""Driver for the cocotb simulation. Run via `scripts\\sim.ps1 -Project 01-blinky`.

The deployed design uses an off-the-shelf AXI GPIO IP, so there's no
custom AXI logic to simulate yet. The placeholder DUT under hw/src/
exists purely to exercise the simulation flow end-to-end.
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

    # runner.test() returns the results.xml path but doesn't raise on
    # failures, so we have to inspect it ourselves and propagate a
    # non-zero exit code if anything failed.
    num_tests, num_failed = get_results(results_xml)
    if num_failed:
        sys.exit(f"{num_failed} of {num_tests} test(s) failed")

if __name__ == "__main__":
    main()
