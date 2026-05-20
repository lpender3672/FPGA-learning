#!/bin/bash
# One-time setup inside WSL: install verilator, build a Linux venv, install
# cocotb + cocotbext-axi. Idempotent.
#
# Usage (from WSL):
#   bash scripts/setup-sim.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_DIR="$REPO_ROOT/.venv"

# 1. System packages.
# `venv` is in the stdlib but Ubuntu splits `ensurepip` (needed to bootstrap
# pip inside a new venv) into the python3-venv package.
need_apt=()
command -v python3 >/dev/null              || need_apt+=(python3)
python3 -c "import ensurepip" 2>/dev/null  || need_apt+=(python3-venv)
command -v pip3 >/dev/null                 || need_apt+=(python3-pip)

if [ "${#need_apt[@]}" -gt 0 ]; then
    echo "==> installing system packages: ${need_apt[*]}"
    sudo apt-get update
    sudo apt-get install -y "${need_apt[@]}"
fi

# 2. Verilator: needs to be >= 5.022 for cocotb 2.x's VPI shim. Ubuntu 24.04
# ships 5.020 in apt, which is too old, so we build from source if needed.
# Pinned to a known-good stable release for reproducibility.
VERILATOR_MIN_MAJOR=5
VERILATOR_MIN_MINOR=022
VERILATOR_PIN_TAG=v5.026

verilator_too_old() {
    if ! command -v verilator >/dev/null; then return 0; fi
    local v ma mi
    v="$(verilator --version | head -1 | awk '{print $2}')"
    ma="${v%%.*}"
    mi="${v#*.}"; mi="${mi%% *}"; mi="${mi%%-*}"
    if [ "$ma" -lt "$VERILATOR_MIN_MAJOR" ]; then return 0; fi
    if [ "$ma" -eq "$VERILATOR_MIN_MAJOR" ] && [ "$((10#$mi))" -lt "$((10#$VERILATOR_MIN_MINOR))" ]; then return 0; fi
    return 1
}

if verilator_too_old; then
    echo "==> verilator missing or older than ${VERILATOR_MIN_MAJOR}.${VERILATOR_MIN_MINOR}; building $VERILATOR_PIN_TAG from source"
    sudo apt-get install -y git make autoconf g++ flex bison libfl2 libfl-dev help2man ccache zlib1g zlib1g-dev
    VBUILD="$REPO_ROOT/.verilator-build"
    if [ ! -d "$VBUILD/.git" ]; then
        git clone https://github.com/verilator/verilator.git "$VBUILD"
    fi
    cd "$VBUILD"
    git fetch --tags
    git checkout "$VERILATOR_PIN_TAG"
    autoconf
    ./configure
    make -j"$(nproc)"
    sudo make install
    cd "$REPO_ROOT"
    if verilator_too_old; then
        echo "ERROR: verilator install still too old after source build" >&2
        exit 1
    fi
fi

# 2. Detect & reject a leftover Windows venv (Scripts/ instead of bin/)
if [ -d "$VENV_DIR/Scripts" ] && [ ! -d "$VENV_DIR/bin" ]; then
    echo "ERROR: $VENV_DIR is a Windows venv from a previous run." >&2
    echo "Delete it and re-run:" >&2
    echo "  rm -rf '$VENV_DIR'" >&2
    exit 1
fi

# 3. Create venv if missing
if [ ! -d "$VENV_DIR" ]; then
    echo "==> creating Linux venv at $VENV_DIR"
    python3 -m venv "$VENV_DIR"
fi

VENV_PY="$VENV_DIR/bin/python"
[ -x "$VENV_PY" ] || { echo "venv python not found at $VENV_PY"; exit 1; }

# 4. Install Python packages
echo "==> upgrading pip"
"$VENV_PY" -m pip install --upgrade pip

echo "==> installing cocotb + cocotbext-axi + pytest"
"$VENV_PY" -m pip install --upgrade "cocotb>=2.0" cocotbext-axi pytest

echo
echo "==> done."
echo "    verilator: $(verilator --version | head -n1)"
echo "    venv:      $VENV_DIR"
echo "    activate:  source $VENV_DIR/bin/activate"
