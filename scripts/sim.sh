#!/bin/bash
# Run the cocotb simulation for one project inside WSL.
#
# Usage (from WSL):
#   bash scripts/sim.sh -p 01-blinky

set -euo pipefail

usage() { echo "Usage: $0 -p <project>" >&2; exit 2; }

PROJECT=""
while getopts "p:" opt; do
    case "$opt" in
        p) PROJECT="$OPTARG" ;;
        *) usage ;;
    esac
done
[ -z "$PROJECT" ] && usage

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_DIR="$REPO_ROOT/.venv"
PROJECT_DIR="$REPO_ROOT/$PROJECT"
RUNNER="$PROJECT_DIR/sim/runner.py"

[ -d "$PROJECT_DIR" ] || { echo "Project not found: $PROJECT_DIR"; exit 1; }
[ -d "$VENV_DIR/bin" ] || { echo ".venv not found or not a Linux venv. Run scripts/setup-sim.sh first."; exit 1; }
[ -f "$RUNNER" ]     || { echo "No sim/runner.py in $PROJECT_DIR"; exit 1; }
command -v verilator >/dev/null || { echo "verilator not on PATH. Run scripts/setup-sim.sh"; exit 1; }

# Clean stale build dir. Verilator-generated Vtop.mk hard-codes absolute
# paths to cocotb's verilator.cpp; if the venv was rebuilt or moved, those
# paths go stale and 'make' fails with "no rule to make target". Wiping the
# dir is cheap (a few seconds) and avoids a confusing failure mode.
BUILD_DIR="$PROJECT_DIR/build/sim"
if [ -d "$BUILD_DIR" ]; then
    rm -rf "$BUILD_DIR"
fi

echo "==> [$PROJECT] simulating with verilator"
source "$VENV_DIR/bin/activate"
python "$RUNNER"
echo "==> [$PROJECT] sim PASS"
